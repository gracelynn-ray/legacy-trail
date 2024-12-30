import UIKit
import MapKit
import FirebaseFirestore

protocol LocationSelectionDelegate: AnyObject {
    func didSelectLocation(_ location: GeoPoint?)
}

// View controller to allow user to pick a location for a new memory.
class MapViewController: UIViewController, MKMapViewDelegate {

    let mapView = MKMapView()
    let confirmButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    var selectedCoordinate: CLLocationCoordinate2D?
    var delegate: LocationSelectionDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Sets up components programmatically.
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.systemRed
        cancelButton.layer.cornerRadius = 25
        cancelButton.clipsToBounds = true
        cancelButton.addTarget(self, action: #selector(cancelButtonPressed), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        confirmButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        confirmButton.tintColor = .white
        confirmButton.backgroundColor = UIColor.darkGray
        confirmButton.layer.cornerRadius = 25
        confirmButton.clipsToBounds = true
        confirmButton.addTarget(self, action: #selector(confirmButtonPressed), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confirmButton)

        // Sets up constraints programmatically.
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            confirmButton.widthAnchor.constraint(equalToConstant: 50),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),
            confirmButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            cancelButton.widthAnchor.constraint(equalToConstant: 50),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView.addGestureRecognizer(longPressGesture)
        
        // Center on location if memory already has one.
        if let coordinate = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
            
            // Set the map's region to center on the coordinate.
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000000, longitudinalMeters: 1000000)
            mapView.setRegion(region, animated: true)
        }
    }

    // Selects spot pressed as new location.
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let locationInView = gesture.location(in: mapView)
            let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)

            selectedCoordinate = coordinate
            mapView.removeAnnotations(mapView.annotations)

            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
        }
    }

    // Updates new memory's location.
    @objc func confirmButtonPressed() {
        guard let coordinate = selectedCoordinate else {
            delegate.didSelectLocation(nil)
            dismiss(animated: true)
            return
        }

        let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        delegate.didSelectLocation(geoPoint)
        dismiss(animated: true)
    }
    
    // Does not update new coordinate.
    @objc func cancelButtonPressed() {
        dismiss(animated: true)
    }
    
    // Allows user to remove location from a memory.
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        mapView.removeAnnotation(annotation)
        selectedCoordinate = nil
    }
}
