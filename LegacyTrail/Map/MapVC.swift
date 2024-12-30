import UIKit
import MapKit
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import SDWebImage

// View controller to display map of user.
class MapVC: UIViewController, CLLocationManagerDelegate, Deletable, Updatable{

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var goToMyLocation: UIButton! // Button centers view on locations.
    
    let locationManager = CLLocationManager()
    var traveledLocations = [CLLocationCoordinate2D]()
    
    var selectedMemory: String! // Used to pull up memory details.
    
    var excludedRegions = [MKPolygon]() // Highlighted states.
    let statePolygons = GeoJSONParser.parseStates(from: "us_states")
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = MKPointOfInterestFilter.excludingAll
        mapView.isRotateEnabled = false
        goToMyLocation.setImage(UIImage(systemName: "location.fill"), for: .normal)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        setupLocationManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let selectedAnnotation = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selectedAnnotation, animated: true)
        }
        
        goToMyLocation.setImage(UIImage(systemName: "location.fill"), for: .normal)
        loadUserMemories()
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func setupBlurOverlay() {
        // Determines which states to highlight.
        excludedRegions.removeAll()
        for traveledLocation in traveledLocations {
            for state in statePolygons {
                if isLocation(traveledLocation, inside: state) {
                    excludedRegions.append(state)
                    break
                }
            }
        }

        let blurOverlay = BlurredMapOverlay()
        mapView.addOverlay(blurOverlay)
    }
    
    func isLocation(_ location: CLLocationCoordinate2D, inside polygon: MKPolygon) -> Bool {
        let renderer = MKPolygonRenderer(polygon: polygon)
        let point = MKMapPoint(location)
        let mapPoint = renderer.point(for: point)
        return renderer.path.contains(mapPoint)
    }
    
    // Centers map on user's memories when button is pressed.
    @IBAction func centerMapOnUserLocation(_ sender: Any) {
        centerMapOnAnnotations(coordinates: traveledLocations)
    }
    
    // Changes center location icon if user moves map.
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        goToMyLocation.setImage(UIImage(systemName: "location"), for: .normal)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Places pins for user's memories and bucket list items.
    private func loadUserMemories() {
        mapView.removeAnnotations(mapView.annotations)
        
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("memories").whereField("uid", isEqualTo: userId).getDocuments { (snapshot, error) in
            if error != nil { return }
            guard let documents = snapshot?.documents else { return }
            
            self.traveledLocations.removeAll()
            
            for document in documents {
                let data = document.data()
                if let geoPoint = data["location"] as? GeoPoint {
                    let pin = MapPin(memoryId: document.documentID)
                    pin.coordinate = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                                            
                    self.mapView.addAnnotation(pin)
                    self.traveledLocations.append(pin.coordinate)
                }
            }
            
            DispatchQueue.main.async {
                self.centerMapOnAnnotations(coordinates: self.traveledLocations)
            }
            
            self.mapView.removeOverlays(self.mapView.overlays)
            self.setupBlurOverlay()
        }
        
        db.collection("bucket").document(userId).getDocument { (document, error) in
            if error != nil { return }
            
            guard let data = document?.data(), let locations = data["locations"] as? [GeoPoint] else { return }
            
            for geoPoint in locations {
                let bucketPin = MKPointAnnotation()
                bucketPin.coordinate = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                self.mapView.addAnnotation(bucketPin)
            }
        }
    }
    
    private func centerMapOnAnnotations(coordinates: [CLLocationCoordinate2D]) {
        // Centers map on user's location if no memories.
        guard !coordinates.isEmpty else {
            guard let userLocation = mapView.userLocation.location else { return }
            let camera = MKMapCamera(lookingAtCenter: userLocation.coordinate, fromDistance: 1000000, pitch: 0, heading: 0)
            mapView.setCamera(camera, animated: true)
            self.goToMyLocation.setImage(UIImage(systemName: "location.fill"), for: .normal)
            return
        }
        
        // Centers map on user's memory locations.
        var zoomRect = MKMapRect.null
        for coordinate in coordinates {
            let annotationPoint = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0.1, height: 0.1)
                zoomRect = zoomRect.union(pointRect)
        }
        let centerCoordinate = MKCoordinateRegion(zoomRect).center
        let camera = MKMapCamera()
        camera.centerCoordinate = centerCoordinate
        camera.altitude = 20000000
        camera.pitch = 0
        camera.heading = 0
        UIView.animate(withDuration: 2.0, delay: 0, options: [.curveEaseInOut], animations: {
            self.mapView.camera = camera
            self.goToMyLocation.setImage(UIImage(systemName: "location.fill"), for: .normal)
        }, completion: nil)
    }
    
    // Loads memory details and segues to details screen.
    private func loadMemoryDataAndSegue() {
        let db = Firestore.firestore()
        db.collection("memories").document(selectedMemory).getDocument { (document, error) in
            if error != nil { return }
            guard let document = document, document.exists else { return }

            let data = document.data()!
            let title = data["title"] as? String ?? ""
            let description = data["description"] as? String ?? ""
            var date = ""
            var timestamp: Timestamp?
                
            if let ts = data["date"] as? Timestamp {
                timestamp = ts
                date = self.formatDate(date: ts)
            }
            
            // Downloads memory image. Uses default unavailable image if not downloadable.
            if let imageURLString = data["imageURL"] as? String, let imageURL = URL(string: imageURLString) {
                SDWebImageDownloader.shared.downloadImage(with: imageURL) { (downloadedImage, _, _, _) in
                    let image = downloadedImage ?? UIImage(named: "unavailable")
                    let memory = Memory(id: document.documentID, title: title, description: description, date: date, timestamp: timestamp, image: image!)
                    self.performSegue(withIdentifier: "DetailSegue", sender: memory)
                }
            } else {
                let memory = Memory(id: document.documentID, title: title, description: description, date: date, timestamp: timestamp, image: UIImage(named: "unavailable")!)
                self.performSegue(withIdentifier: "DetailSegue", sender: memory)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DetailSegue", let nextVC = segue.destination as? MemoryDetailViewController, let memory = sender as? Memory {
            nextVC.memory = memory
            nextVC.isOwner = true
            nextVC.delegate = self
        }
    }
    
    private func formatDate(date: Timestamp) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date.dateValue())
    }
    
    func delete() {
        loadUserMemories()
    }
    
    func update(newTitle: String, newDescription: String) {
        loadUserMemories()
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is BlurredMapOverlay {
            return BlurredMapOverlayRenderer(overlay: overlay, excludedRegions: excludedRegions)
        } else if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.clear
            renderer.strokeColor = UIColor.red
            renderer.lineWidth = 1
            return renderer
        }
        return MKOverlayRenderer()
    }
    
    // Places a bucket list item if user holds a spot on the map.
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            let bucketPin = MKPointAnnotation()
            bucketPin.coordinate = coordinate
            mapView.addAnnotation(bucketPin)
            
            guard let userId = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            let geopoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            db.collection("bucket").document(userId).setData(["locations": FieldValue.arrayUnion([geopoint])], merge: true) { error in
                if error != nil { return }
            }
        }
    }
    
    // Changes pin color based on map pin type.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let identifier = "MapPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            annotationView?.annotation = annotation
        }
        
        if annotation is MapPin {
            annotationView?.markerTintColor = .red // Red for memories
        } else {
            annotationView?.markerTintColor = .blue // Blue for bucket list
        }
        
        return annotationView
    }
    
    // Deelte a bucket list if user presses pin.
    private func deleteBucketListItem(at coordinate: CLLocationCoordinate2D) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let geopoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        db.collection("bucket").document(userId).updateData(["locations": FieldValue.arrayRemove([geopoint])]) { error in
            if error != nil { return }
        }
    }
}


// Map pins store the memory ID so that the details can be pulled up.
class MapPin: MKPointAnnotation {
    let memoryId: String
    
    init(memoryId: String) {
        self.memoryId = memoryId
    }
}

// Pulls up memory details or brings up action sheet when pin is selected.
extension MapVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let pin = view.annotation as? MapPin {
            selectedMemory = pin.memoryId
            loadMemoryDataAndSegue()
        } else if let bucketPin = view.annotation as? MKPointAnnotation {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete Bucket List Item", style: .destructive, handler: { _ in
                self.deleteBucketListItem(at: bucketPin.coordinate)
                mapView.removeAnnotation(bucketPin)
            }))
            present(alert, animated: true)
        }
        
        mapView.deselectAnnotation(view.annotation, animated: true)
    }
}
