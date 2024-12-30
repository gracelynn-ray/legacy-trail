import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// View controller that displays user's profile page.
class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBAction func MemoryButtonPressed(_ sender: Any) {
    }
    
    @IBAction func TimeCapsulesButtonPressed(_ sender: Any) {
    }
    
    @IBAction func BadgesButtonPressed(_ sender: Any) {
    }
    
    @IBAction func SettingsButtonPressed(_ sender: Any) {
    }
    
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var UserMailLabel: UILabel!
    @IBOutlet weak var UserNameLabel: UILabel!
        
    // Grabs username associated with the user logged in.
    func fetchCurrentUserUsername(completion: @escaping (String?) -> Void) {
        let uid = Auth.auth().currentUser?.uid
        if uid == nil {
            performSegue(withIdentifier: "LogoutSegue", sender: self)
        } else {
            let db = Firestore.firestore()
            db.collection("users").whereField("uid", isEqualTo: uid!).getDocuments { (snapshot, error) in
                if error != nil {
                    completion(nil)
                } else if let snapshot = snapshot, snapshot.documents.count == 1 {
                    let document = snapshot.documents.first!
                    let username = document.data()["username"] as? String ?? ""
                    completion(username)
                    self.UserNameLabel.text = username
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        profilePicture.layer.cornerRadius = profilePicture.frame.width / 2
        profilePicture.clipsToBounds = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(profilePictureTapped))
        profilePicture.isUserInteractionEnabled = true
        profilePicture.addGestureRecognizer(tapGesture)
        
        let backButton = UIBarButtonItem()
        backButton.tintColor = .label
        navigationItem.backBarButtonItem = backButton
        
        let bellButton = UIBarButtonItem(
            image: UIImage(systemName: "bell"),
            style: .plain,
            target: self,
            action: #selector(bellButtonPressed)
        )
        
        bellButton.tintColor = .label
        navigationItem.rightBarButtonItem = bellButton
    }
    
    @objc func bellButtonPressed() {
        performSegue(withIdentifier: "NotificationsSegue", sender: self)
    }
    
    // Allows user to change profile picture when tapping the icon.
    @objc func profilePictureTapped() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Option to choose a new photo.
        let choosePhotoAction = UIAlertAction(title: "Choose New Photo", style: .default) { _ in
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = true
            self.present(imagePicker, animated: true, completion: nil)
        }
        
        // Option to delete the current photo.
        let deletePhotoAction = UIAlertAction(title: "Delete Photo", style: .destructive) { _ in
            self.deleteProfilePicture()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        actionSheet.addAction(choosePhotoAction)
        actionSheet.addAction(deletePhotoAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    // Pulls up user's photo library.
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        // Grabs the image the user selected from the photo library.
        if let image = info[.editedImage] as? UIImage {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            
            let storageRef = Storage.storage().reference().child("profile_pictures/\(uid).jpg")
            
            storageRef.putData(imageData, metadata: nil) { metadata, error in
                if error != nil { return }
                
                storageRef.downloadURL { url, error in
                    guard let url = url, error == nil else { return }
                    
                    if let user = Auth.auth().currentUser {
                        let changeRequest = user.createProfileChangeRequest()
                        changeRequest.photoURL = url
                        changeRequest.commitChanges { error in
                            if error == nil {
                                // Associates photo URL with profile.
                                self.profilePicture.sd_setImage(with: url, placeholderImage: UIImage(systemName: "person.crop.circle.fill"))
                                NotificationCenter.default.post(name: NSNotification.Name("ProfilePictureUpdated"), object: nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Allows user to remove profile picture and revert to old one.
    private func deleteProfilePicture() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        
        let storageRef = Storage.storage().reference().child("profile_pictures/\(uid).jpg")
        
        // Delete the profile picture from Firebase Storage
        storageRef.delete { error in
            if error != nil { return }
            
            // Update Firebase to remove the photo url
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.photoURL = nil
            changeRequest.commitChanges { error in
                if error == nil {
                    self.profilePicture.image = UIImage(systemName: "person.crop.circle.fill")
                    NotificationCenter.default.post(name: NSNotification.Name("ProfilePictureUpdated"), object: nil)
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchCurrentUserUsername { username in
            self.UserMailLabel.text = Auth.auth().currentUser?.email
            if let username = username {
                self.UserNameLabel.text = username
            }
        }
        fetchProfilePicture()
        pushNotificationsForCurrentUser()
        checkUnreadNotifications()
    }
    
    private func pushNotificationsForCurrentUser() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()

        db.collection("preferences").document(userId).getDocument { snapshot, error in
            if error != nil { return }

            let preferences = snapshot?.data() ?? ["ready": true, "received": true, "day": true]

            // Check each preference before invoking the respective method.
            if preferences["ready"] as? Bool == true {
                self.checkReadyTimeCapsules()
            }

            if preferences["received"] as? Bool == true {
                self.checkReceivedTimeCapsules()
            }

            if preferences["day"] as? Bool == true {
                self.checkOnThisDayMemories()
            }
        }
    }
    
    private func checkReadyTimeCapsules() {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        // Fetch the username of the current user
        db.collection("users")
            .whereField("uid", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if error != nil { return }
                guard let documents = snapshot?.documents, let userDocument = documents.first else { return }

                let username = userDocument.data()["username"] as? String ?? ""

                // Define today's end timestamp.
                let endOfToday = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60 - 1)

                // Query capsules where the username is in the contacts array
                db.collection("capsules")
                    .whereField("contacts", arrayContains: username)
                    .whereField("scheduledDate", isLessThanOrEqualTo: endOfToday)
                    .getDocuments { snapshot, error in
                        if error != nil { return }
                        guard let documents = snapshot?.documents else { return }

                        for document in documents {
                            let capsuleId = document.documentID
                            let ownerUid = document.data()["owner"] as? String ?? ""

                            // Fetch the owner's username from the users collection.
                            let db = Firestore.firestore()
                            db.collection("users")
                                .whereField("uid", isEqualTo: ownerUid)
                                .getDocuments { snapshot, error in
                                    if error != nil { return }

                                    guard let documents = snapshot?.documents, let userDocument = documents.first else { return }

                                    let ownerUsername = userDocument.data()["username"] as? String ?? "Someone"
                                    let title = "📦 \(ownerUsername)'s Time Capsule Ready!"
                                    let description = "\(ownerUsername)'s time capsule is now available! Explore its contents on your capsules page."

                                    // Check if notification already exists
                                    self.checkNotificationExists(for: capsuleId, type: 1) { exists in
                                        if !exists {
                                            self.createNotification(title: title, description: description, type: 1, selectedMemory: capsuleId)
                                            DispatchQueue.main.async {
                                                self.updateNavigationBarBadge(hasUnread: true)
                                            }
                                        }
                                    }
                                }
                        }
                    }
            }
    }
    
    private func checkReceivedTimeCapsules() {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        // Fetch the username of the current user
        db.collection("users")
            .whereField("uid", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if error != nil { return }
                guard let documents = snapshot?.documents, let userDocument = documents.first else { return }

                let username = userDocument.data()["username"] as? String ?? ""

                // Query capsules where the username is in the contacts array.
                db.collection("capsules")
                    .whereField("contacts", arrayContains: username)
                    .getDocuments { snapshot, error in
                        if error != nil { return }
                        guard let documents = snapshot?.documents else { return }

                        for document in documents {
                            let capsuleId = document.documentID
                            let ownerUid = document.data()["owner"] as? String ?? ""

                            // Fetch the owner's username from the users collection.
                            let db = Firestore.firestore()
                            db.collection("users")
                                .whereField("uid", isEqualTo: ownerUid)
                                .getDocuments { snapshot, error in
                                    if error != nil { return }
                                    guard let documents = snapshot?.documents, let userDocument = documents.first else { return }

                                    let ownerUsername = userDocument.data()["username"] as? String ?? "Someone"
                                    let title = "🎁 New Time Capsule from \(ownerUsername)"
                                    let date = self.formatDate(document.data()["scheduledDate"] as? Timestamp ?? Timestamp())
                                    let description = "\(ownerUsername) has included you in their time capsule! It will unlock on \(date)."

                                    // Check if notification already exists.
                                    self.checkNotificationExists(for: capsuleId, type: 0) { exists in
                                        if !exists {
                                            self.createNotification(title: title, description: description, type: 0, selectedMemory: capsuleId)
                                            DispatchQueue.main.async {
                                                self.updateNavigationBarBadge(hasUnread: true)
                                            }
                                        }
                                    }
                                }
                        }
                    }
            }
    }
    
    private func checkOnThisDayMemories() {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        let today = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: today)
        let month = calendar.component(.month, from: today)

        db.collection("memories")
            .whereField("uid", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if error != nil { return }
                guard let documents = snapshot?.documents else { return }

                for document in documents {
                    let data = document.data()
                    let memoryDate = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Check if the day and month match.
                    if calendar.component(.day, from: memoryDate) == day &&
                        calendar.component(.month, from: memoryDate) == month &&
                        calendar.component(.year, from: memoryDate) < calendar.component(.year, from: today) {

                        let yearsAgo = calendar.component(.year, from: today) - calendar.component(.year, from: memoryDate)
                        let memoryId = document.documentID
                        let title = "On This Day 🎉"
                        let description = "Relive a memory from \(yearsAgo) years ago! Tap to view this special moment."

                        // Check if notification already exists.
                        self.checkNotificationExists(for: memoryId, type: 2) { exists in
                            if !exists {
                                self.createNotification(title: title, description: description, type: 2, selectedMemory: memoryId)
                                DispatchQueue.main.async {
                                    self.updateNavigationBarBadge(hasUnread: true)
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private func createNotification(title: String, description: String, type: Int, selectedMemory: String?) {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        let notification: [String: Any] = [
            "userId": userId,
            "title": title,
            "description": description,
            "type": type,
            "read": false,
            "selectedMemory": selectedMemory ?? "",
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("notifications").addDocument(data: notification) { error in
            if let error = error {
                print("Error creating notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkNotificationExists(for selectedMemory: String, type: Int, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? ""

        db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("type", isEqualTo: type)
            .whereField("selectedMemory", isEqualTo: selectedMemory)
            .getDocuments { snapshot, error in
                if error != nil {
                    completion(false)
                    return
                }

                completion(snapshot?.documents.isEmpty == false)
            }
    }
    
    private func checkUnreadNotifications() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()

        // Query for unread notifications.
        db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("read", isEqualTo: false)
            .getDocuments { snapshot, error in
                if error != nil { return }

                let unreadCount = snapshot?.documents.count ?? 0
                DispatchQueue.main.async {
                    self.updateNavigationBarBadge(hasUnread: unreadCount > 0)
                }
            }
    }
    
    private func updateNavigationBarBadge(hasUnread: Bool) {
        guard let barButtonView = navigationItem.rightBarButtonItem?.value(forKey: "view") as? UIView else { return }

        if let existingBadge = barButtonView.viewWithTag(999) {
            existingBadge.removeFromSuperview()
        }

        if hasUnread {
            let badgeSize: CGFloat = 10
            let badge = UIView(frame: CGRect(x: barButtonView.frame.width - badgeSize, y: 0, width: badgeSize, height: badgeSize))
            badge.backgroundColor = .red
            badge.layer.cornerRadius = badgeSize / 2
            badge.clipsToBounds = true
            badge.tag = 999
            barButtonView.addSubview(badge)
        }
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        let date = timestamp.dateValue()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    // Sets image view as user's profile picture or default picture.
    private func fetchProfilePicture() {
        if let user = Auth.auth().currentUser, let profilePictureURL = user.photoURL {
            profilePicture.sd_setImage(with: profilePictureURL, placeholderImage: UIImage(systemName: "person.crop.circle.fill"))
        } else {
            profilePicture.image = UIImage(systemName: "person.crop.circle.fill")
        }
    }
    
    
    @IBAction func logoutButtonPressed(_ sender: Any) {
        do {
            try Auth.auth().signOut()
            self.performSegue(withIdentifier: "LogoutSegue", sender: nil)
        } catch {
            print("Logout error")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "MemoriesSegue",
           let nextVC = segue.destination as? MemoriesViewController {
            nextVC.isOwner = true
            nextVC.userId = Auth.auth().currentUser!.uid
            nextVC.date = Date()
       }
    }
}
