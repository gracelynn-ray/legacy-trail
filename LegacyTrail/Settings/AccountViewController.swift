import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// View controller that displays account settings.
class AccountViewController: UIViewController {

    @IBAction func ChangeEmailButtonPressed(_ sender: Any) {
    }
    
    @IBAction func ChangeUsernameButtonPressed(_ sender: Any) {
    }
    
    @IBAction func ChangePasswordButtonPressed(_ sender: Any) {
    }
    
    // Alert to confirm account deletion.
    @IBAction func DeleteAccountButtonPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete Account", message: "Are you sure you want to delete your account? This action cannot be undone.", preferredStyle: .alert)
                
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
            self.deleteAccount()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }

    // Deletes user's account and logs them out.
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let id = user.uid
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        // Delete profile picture from storage.
        let pfp = storage.reference(withPath: "profile_pictures/\(user.uid).jpg")
        pfp.delete { error in
            if let error = error {
                print("Error deleting image: \(error.localizedDescription)")
            }
        }
        
        // Delete memories and images associated with memories.
        deleteMemoriesAndImages(userID: id, db: db, storage: storage) { [weak self] in
            // Delete notifications.
            self?.deleteNotifications(userID: id, db: db) {
                // Delete user data.
                self?.deleteUserData(userID: id, db: db) { username in
                    guard let username = username else {
                        return
                    }
                    
                    // Delete owned capsules.
                    self?.deleteOwnedCapsules(userID: id, db: db) {
                        // Remove user from other capsules' contacts.
                        self?.removeUserFromContacts(username: username, db: db) {
                            // Delete the bucket list.
                            self?.deleteBucketList(userID: id, db: db) {
                                // Sign out and delete user.
                                self?.signOutAndDeleteUser(user: user)
                            }
                        }
                    }
                }
            }
        }
    }

    // Deletes all memories and images owned by the user.
    private func deleteMemoriesAndImages(userID: String, db: Firestore, storage: Storage, completion: @escaping () -> Void) {
        let memoriesRef = db.collection("memories").whereField("uid", isEqualTo: userID)
        memoriesRef.getDocuments { snapshot, error in
            if let error = error {
                completion()
                return
            }
            
            let dispatchGroup = DispatchGroup()
            
            snapshot?.documents.forEach { document in
                let imagePath = document.data()["imagePath"] as? String ?? ""
                if !imagePath.isEmpty {
                    dispatchGroup.enter()
                    storage.reference(withPath: imagePath).delete { error in
                        if error != nil { return }
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.enter()
                document.reference.delete { error in
                    if error != nil { return }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion()
            }
        }
    }
    
    // Deletes all user's notifications.
    private func deleteNotifications(userID: String, db: Firestore, completion: @escaping () -> Void) {
        let notificationsRef = db.collection("notifications")
        let query = notificationsRef.whereField("userId", isEqualTo: userID)
        
        query.getDocuments { (snapshot, error) in
            if let error = error {
                completion()
                return
            }
            
            guard let snapshot = snapshot else {
                completion()
                return
            }
            
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { batchError in
                if let batchError = batchError {
                    print("Error deleting notifications: \(batchError.localizedDescription)")
                }
                completion()
            }
        }
    }

    // Delets user data stored for user.
    private func deleteUserData(userID: String, db: Firestore, completion: @escaping (String?) -> Void) {
        let usersRef = db.collection("users").whereField("uid", isEqualTo: userID)
        usersRef.getDocuments { snapshot, error in
            if let error = error {
                completion(nil)
                return
            }
            
            guard let document = snapshot?.documents.first, let username = document.data()["username"] as? String else {
                completion(nil)
                return
            }
            
            document.reference.delete { _ in
                completion(username)
            }
        }
    }

    // Delete time capsules owned by the user.
    private func deleteOwnedCapsules(userID: String, db: Firestore, completion: @escaping () -> Void) {
        let ownedCapsulesRef = db.collection("capsules").whereField("owner", isEqualTo: userID)
        ownedCapsulesRef.getDocuments { snapshot, error in
            if let error = error {
                completion()
                return
            }
            
            let dispatchGroup = DispatchGroup()
            
            snapshot?.documents.forEach { document in
                dispatchGroup.enter()
                document.reference.delete { _ in
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion()
            }
        }
    }
    
    // Delete user's bucket list.
    private func deleteBucketList(userID: String, db: Firestore, completion: @escaping () -> Void) {
        let bucketRef = db.collection("bucket").document(userID)
        bucketRef.delete { _ in
            completion()
        }
    }

    // Remove the user from all time capsules with the user as a contact.
    private func removeUserFromContacts(username: String, db: Firestore, completion: @escaping () -> Void) {
        let capsulesWithContactRef = db.collection("capsules").whereField("contacts", arrayContains: username)
        capsulesWithContactRef.getDocuments { snapshot, error in
            if error != nil {
                completion()
                return
            }
            
            let dispatchGroup = DispatchGroup()
            
            snapshot?.documents.forEach { document in
                var contacts = document.data()["contacts"] as? [String] ?? []
                if let index = contacts.firstIndex(of: username) {
                    contacts.remove(at: index)
                    dispatchGroup.enter()
                    document.reference.updateData(["contacts": contacts]) { error in
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion()
            }
        }
    }

    // Log the user out and delete the account.
    private func signOutAndDeleteUser(user: User) {
        do {
            try Auth.auth().signOut()
            self.performSegue(withIdentifier: "LogoutSegue", sender: nil)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        user.delete { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}
