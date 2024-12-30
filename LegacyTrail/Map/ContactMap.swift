import UIKit
import MapKit
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import SDWebImage

// View controller to display map of a received time capsule.
class ContactMap: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, Updatable, Deletable {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var goToMyLocation: UIButton! // Button centers view on locations.
    
    let locationManager = CLLocationManager()
    var traveledLocations = [CLLocationCoordinate2D]()
    
    var userId = "" // User ID of the owner of these memories.
    var date: Date! // Only shows memories before cut off date.
    var isShareable = true
    
    var selectedMemory: String!
    
    var excludedRegions = [MKPolygon]() // Highlights regions that the user has been to.
    let statePolygons = GeoJSONParser.parseStates(from: "us_states") // Parses locations in JSON.
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = MKPointOfInterestFilter.excludingAll
        mapView.isRotateEnabled = false
        
        setupLocationManager()
        
        navigationItem.title = "Map"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont(name: "PlayfairDisplay-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let selectedAnnotation = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selectedAnnotation, animated: true)
        }
        
        goToMyLocation.setImage(UIImage(systemName: "location"), for: .normal)
        loadUserMemories()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // Darkens entire map except visited regions.
    private func setupBlurOverlay() {
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
    
    // Checks if coordinate is within region.
    private func isLocation(_ location: CLLocationCoordinate2D, inside polygon: MKPolygon) -> Bool {
        let renderer = MKPolygonRenderer(polygon: polygon)
        let point = MKMapPoint(location)
        let mapPoint = renderer.point(for: point)
        return renderer.path.contains(mapPoint)
    }
    
    // Centers map view on user's pins when button is tapped.
    @IBAction func centerMapOnLocation(_ sender: Any) {
        centerMapOnAnnotations(coordinates: traveledLocations)
    }
    
    // Unfills location center button.
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        goToMyLocation.setImage(UIImage(systemName: "location"), for: .normal)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Adds pins of map for memories in their location.
    private func loadUserMemories() {
        mapView.removeAnnotations(mapView.annotations)
        let db = Firestore.firestore()
        
        // Finds memories owned by user and before cutoff date.
        db.collection("memories")
                    .whereField("uid", isEqualTo: userId)
                    .whereField("date", isLessThanOrEqualTo: Timestamp(date: Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!)).getDocuments { (snapshot, error) in
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
    }
    
    // Centers map's view so all locations are viewable.
    private func centerMapOnAnnotations(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            guard let userLocation = mapView.userLocation.location else { return }
            let camera = MKMapCamera(lookingAtCenter: userLocation.coordinate, fromDistance: 1000000, pitch: 0, heading: 0)
            mapView.setCamera(camera, animated: true)
            self.goToMyLocation.setImage(UIImage(systemName: "location.fill"), for: .normal)
            return
        }
        
        // Adds coordinates of all memories to allow view to center on it.
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
    
    // Pulls up memory details for selected memory.
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

            if let imageURLString = data["imageURL"] as? String, let imageURL = URL(string: imageURLString) {
                SDWebImageDownloader.shared.downloadImage(with: imageURL) { (downloadedImage, _, _, _) in
                    let image = downloadedImage ?? UIImage(named: "unavailable")
                    let memory = Memory(id: document.documentID, title: title, description: description, date: date, timestamp: timestamp, image: image!)
                    self.performSegue(withIdentifier: "DetailSegue2", sender: memory)
                }
            } else {
                let memory = Memory(id: document.documentID, title: title, description: description, date: date, timestamp: timestamp, image: UIImage(named: "unavailable")!)
                self.performSegue(withIdentifier: "DetailSegue2", sender: memory)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DetailSegue2", let nextVC = segue.destination as? MemoryDetailViewController, let memory = sender as? Memory {
            nextVC.memory = memory
            nextVC.isOwner = false
            nextVC.delegate = self
            nextVC.isShareable = self.isShareable
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
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        
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
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let pin = view.annotation as? MapPin {
            selectedMemory = pin.memoryId
            loadMemoryDataAndSegue()
            mapView.deselectAnnotation(pin, animated: true)
        }
    }
}
