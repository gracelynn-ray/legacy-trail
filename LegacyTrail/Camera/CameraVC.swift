import UIKit
import AVFoundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Photos

// View controller used to allow users to take and upload photos.
class CameraVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate {
    
    var captureSession: AVCaptureSession!
    var capturePhotoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    let locationManager = CLLocationManager() // Used to set location of image taken.
    
    @IBOutlet weak var uploadPhoto: UIButton! // Opens up photo library.
    @IBOutlet weak var shutterButton: UIButton! // Captures image.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGesture) // Allows user to zoom.
        view.bringSubviewToFront(uploadPhoto)
        view.bringSubviewToFront(shutterButton)
    
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // Sets up camera device to capture photos.
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            capturePhotoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(capturePhotoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(capturePhotoOutput)
                setupPreviewLayer()
                captureSession.startRunning()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // Zooms camera in and out as user pinches.
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
        let zoomFactor = min(max(gesture.scale, 1.0), maxZoomFactor)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoomFactor
            device.unlockForConfiguration()
        } catch {
            print("Error: \(error)")
        }
    }

    // Sets up camera preview.
    private func setupPreviewLayer() {
       previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
       previewLayer.videoGravity = .resizeAspectFill
       
       let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
       let bottomSafeArea = 34.0
       
       previewLayer.frame = CGRect(
           x: 0,
           y: 0,
           width: view.bounds.width,
           height: view.bounds.height - (tabBarHeight + bottomSafeArea)
       )
       
       view.layer.insertSublayer(previewLayer, at: 0)
   }

    // Triggered when shutter button is pressed.
    @IBAction func capturePhoto(_ sender: UIButton) {
        if capturePhotoOutput != nil {
            let settings = AVCapturePhotoSettings()
            capturePhotoOutput.capturePhoto(with: settings, delegate: self)
        } else {
            // Displays error if camera is not found.
            let alert = UIAlertController(title: "Camera Error", message: "Camera not available on this device.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true, completion: nil)
        }
    }
    
    // Allows users to upload an image from their photo library.
    @IBAction func uploadPhotoClicked(_ sender: UIButton) {
        let status = PHPhotoLibrary.authorizationStatus()
        // If user has given photo library access, photo library is pulled up.
        if status == .authorized {
            let imagePickerController = UIImagePickerController()
                imagePickerController.delegate = self
                imagePickerController.sourceType = .photoLibrary
                imagePickerController.allowsEditing = false
                present(imagePickerController, animated: true, completion: nil)
        // Requests photo access if user has not been prompted.
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { _ in }
        // Alerts user to allow photo access.
        } else {
            let alert = UIAlertController(
                title: "Access to Photos Required",
                message: "Please enable access to your photos to create a memory.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
                }
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    // Creates a memory with the selected image.
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            if let asset = info[.phAsset] as? PHAsset {
                let timestamp = asset.creationDate ?? Date()
                let location = asset.location
                let geoPoint = location != nil ? GeoPoint(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude) : nil
                
                // Segues to memory creation screen with photo and photo details.
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "CreateSegue", sender: (selectedImage, timestamp, geoPoint))
                }
            }
        }
        picker.dismiss(animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "CreateSegue",
           let nextVC = segue.destination as? MemoryCreationViewController,
           let (image, timestamp, geoPoint) = sender as? (UIImage, Date, GeoPoint?) {
            // Passes photo details to memory creation screen.
            nextVC.image = image
            nextVC.timestamp = Timestamp(date: timestamp)
            nextVC.location = geoPoint
        }
    }
    
    // Toggles the phone's flash.
    @IBAction func flashPressed(_ sender: Any) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
    }
    
    // Switches between front and rear camera.
    @IBAction func flipCameraPressed(_ sender: Any) {
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)

        let newCamera = (currentInput.device.position == .back ? getCamera(with: .front) : getCamera(with: .back))!
            if let newInput = try? AVCaptureDeviceInput(device: newCamera) {
                captureSession.addInput(newInput)
            }
            captureSession.commitConfiguration()
        }
    
    // Fetches the camera's current positon.
    private func getCamera(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    
    }
}

// Allows user to capture a photo.
extension CameraVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        let capturedImage = UIImage(data: imageData)
        
        if let capturedImage = capturedImage {
            let timestamp = Timestamp(date: Date())
            var geoPoint: GeoPoint? = nil
            
            // Uses user's current location new memory's location.
            if let userLocation = self.locationManager.location?.coordinate {
                geoPoint = GeoPoint(latitude: userLocation.latitude, longitude: userLocation.longitude)
            }

            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "CreateSegue", sender: (capturedImage, timestamp.dateValue(), geoPoint))
            }
        }
    }
}
