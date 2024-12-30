import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import MapKit

// View controller that displays memory creation form.
class MemoryCreationViewController: UIViewController, UITextFieldDelegate, LocationSelectionDelegate {

    let titleField = UITextField()
    let dateLabel = UILabel()
    let imageView = UIImageView()
    let descriptionField = UITextView()
    let createButton = UIButton(type: .system)
    let activityIndicator = UIActivityIndicatorView(style: .medium)
    let locationButton = UIButton(type: .system)
    
    var timestamp: Timestamp?
    var location: GeoPoint?
    var image: UIImage!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleField.delegate = self
        
        // Creates elements and sets up UI programmatically.
        view.backgroundColor = UIColor.systemGroupedBackground
        
        titleField.borderStyle = .none
        titleField.font = UIFont(name: "PlayfairDisplay-Medium", size: 18)
        titleField.placeholder = "Title"
        titleField.layer.borderWidth = 1.0
        titleField.layer.borderColor = UIColor.systemGray4.cgColor
        titleField.layer.cornerRadius = 12
        titleField.backgroundColor = .systemBackground
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.setLeftPaddingPoints(10)
        titleField.setRightPaddingPoints(10)
        view.addSubview(titleField)
        
        dateLabel.font = UIFont(name: "Avenir Light", size: 14)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dateLabel)
        
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.systemGray4.cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        descriptionField.font = UIFont(name: "Avenir Next Medium", size: 16)
        descriptionField.layer.borderWidth = 1.0
        descriptionField.layer.borderColor = UIColor.systemGray4.cgColor
        descriptionField.layer.cornerRadius = 12
        descriptionField.backgroundColor = .systemBackground
        descriptionField.translatesAutoresizingMaskIntoConstraints = false
        descriptionField.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        view.addSubview(descriptionField)
        
        createButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        createButton.tintColor = .white
        createButton.backgroundColor = UIColor.darkGray
        createButton.layer.cornerRadius = 25
        createButton.clipsToBounds = true
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        createButton.layer.shadowRadius = 5
        createButton.layer.shadowOpacity = 0.2
        createButton.addTarget(self, action: #selector(createButtonPressed), for: .touchUpInside)
        createButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(createButton)
        
        locationButton.setTitle("Add/Update Location", for: .normal)
        locationButton.setTitleColor(.systemBlue, for: .normal)
        locationButton.titleLabel?.font = UIFont(name: "Avenir Light", size: 14)
        locationButton.addTarget(self, action: #selector(locationButtonPressed), for: .touchUpInside)
        locationButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(locationButton)
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        // Sets up constraints.
        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleField.heightAnchor.constraint(equalToConstant: 45),
            
            dateLabel.topAnchor.constraint(equalTo: descriptionField.bottomAnchor, constant: 20),
            dateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            dateLabel.heightAnchor.constraint(equalToConstant: 20),
            
            imageView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 15),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.75),
            
            descriptionField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 15),
            descriptionField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            descriptionField.heightAnchor.constraint(equalToConstant: 95),
            
            createButton.widthAnchor.constraint(equalToConstant: 50),
            createButton.heightAnchor.constraint(equalToConstant: 50),
            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            
            activityIndicator.bottomAnchor.constraint(equalTo: createButton.topAnchor, constant: -30),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            locationButton.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 5),
            locationButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            locationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            locationButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let timestamp = timestamp {
            dateLabel.text = formatDate(date: timestamp)
        }
        
        imageView.image = image
    }

    // When memory is created, store the details in database and upload the image.
    @objc func createButtonPressed() {
        activityIndicator.startAnimating()
        
        var memoryData: [String: Any] = [
            "title": titleField.text ?? "",
            "description" : descriptionField.text ?? "",
            "uid" : Auth.auth().currentUser?.uid ?? ""
        ]
        
        // Time and location passed in from camera screen.
        if let timestamp = timestamp {
            memoryData["date"] = timestamp
        }
        
        if let location = location {
            memoryData["location"] = location
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let uniqueID = UUID().uuidString
        let storageRef = Storage.storage().reference().child("images/\(uniqueID).jpg")
        
        // Uploads the image and gets the download URL.
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if error != nil {
                self.activityIndicator.stopAnimating()
                return
            }
            
            storageRef.downloadURL { url, error in
                guard let url = url, error == nil else {
                    self.activityIndicator.stopAnimating()
                    return
                }
                
                // Associates memory with download URL so image can be retrieved later.
                memoryData["imageURL"] = url.absoluteString
                
                // Saves image path so it can be deleted when memory is deleted.
                memoryData["imagePath"] = "images/\(uniqueID).jpg"
                
                let db = Firestore.firestore()
                db.collection("memories").addDocument(data: memoryData) { error in
                    self.activityIndicator.stopAnimating()
                    if let error = error { return }
                    self.dismiss(animated: true)
                }
            }
        }
    }
    
    // Segues to choose memory location on map screen.
    @objc func locationButtonPressed() {
        let mapVC = MapViewController()
        mapVC.delegate = self
        if location != nil {
            mapVC.selectedCoordinate = CLLocationCoordinate2D(latitude: location!.latitude, longitude: location!.longitude)
        }
        mapVC.modalPresentationStyle = .fullScreen
        present(mapVC, animated: true)
    }
    
    // Updates location of memory from location selection screen.
    func didSelectLocation(_ location: GeoPoint?) {
        self.location = location
    }
    
    // Gets the String version of date.
    private func formatDate(date: Timestamp) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date.dateValue())
    }
    
    // Boiler plate code for dismissing keyboard when background is touched.
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
