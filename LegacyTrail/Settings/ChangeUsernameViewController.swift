import UIKit
import FirebaseAuth
import FirebaseFirestore

// View display that allows user to change username.
class ChangeUsernameViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var newUsernameTextField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.isHidden = true
        activityIndicator.hidesWhenStopped = true
        newUsernameTextField.delegate = self
        
        newUsernameTextField.layer.cornerRadius = newUsernameTextField.frame.height / 2
        newUsernameTextField.layer.borderWidth = 0.75
        newUsernameTextField.layer.borderColor = UIColor.black.cgColor
        newUsernameTextField.clipsToBounds = true

        addPadding(to: newUsernameTextField, left: 10, right: 10)
    }

    // Helper function to add left and right padding.
    func addPadding(to textField: UITextField, left: CGFloat, right: CGFloat) {
        // Left padding view.
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: textField.frame.height))
        textField.leftView = leftPaddingView
        textField.leftViewMode = .always
        
        // Right padding view.
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: textField.frame.height))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
    }
    
    // Attempts to update user's username. Through users collection.
    @IBAction func saveButtonPressed(_ sender: Any) {
        errorLabel.text = ""
        guard var newUsername = newUsernameTextField.text, !newUsername.isEmpty else {
            errorLabel.text = "Please enter a new username."
            return
        }
        
        // Username is not case sensitive.
        newUsername = newUsername.lowercased()
        
        activityIndicator.startAnimating()
        
        let db = Firestore.firestore()
        guard let user = Auth.auth().currentUser else {
            errorLabel.text = "User not authenticated."
            activityIndicator.stopAnimating()
            return
        }
        
        db.collection("users").whereField("uid", isEqualTo: user.uid).getDocuments { (snapshot, error) in
            if let error = error {
                self.errorLabel.text = "Error fetching user: \(error.localizedDescription)"
                self.activityIndicator.stopAnimating()
                return
            }
            
            guard let document = snapshot?.documents.first,
                  let oldUsername = document.data()["username"] as? String else {
                self.errorLabel.text = "User not found or username missing."
                self.activityIndicator.stopAnimating()
                return
            }
            
            db.collection("users").whereField("username", isEqualTo: newUsername).getDocuments { (snapshot, error) in
                if let error = error {
                    self.errorLabel.text = "Error checking username: \(error.localizedDescription)"
                    self.activityIndicator.stopAnimating()
                    return
                }
                
                // User cannot change username to one already taken.
                if snapshot?.documents.count ?? 0 > 0 {
                    self.activityIndicator.stopAnimating()
                    self.errorLabel.text = "Username is already taken."
                } else {
                    // Updates to new username in database.
                    document.reference.updateData(["username": newUsername]) { error in
                        if let error = error {
                            self.errorLabel.text = "Error updating username: \(error.localizedDescription)"
                            self.activityIndicator.stopAnimating()
                            return
                        }
                        
                        // Updates username in other user's legacy contact lists.
                        let capsulesRef = db.collection("capsules").whereField("contacts", arrayContains: oldUsername)
                        capsulesRef.getDocuments { (snapshot, error) in
                            if let error = error {
                                self.errorLabel.text = "Error fetching capsules: \(error.localizedDescription)"
                                self.activityIndicator.stopAnimating()
                                return
                            }
                            
                            let batch = db.batch()
                            snapshot?.documents.forEach { capsuleDoc in
                                var contacts = capsuleDoc.data()["contacts"] as? [String] ?? []
                                
                                if let index = contacts.firstIndex(of: oldUsername) {
                                    contacts[index] = newUsername
                                    batch.updateData(["contacts": contacts], forDocument: capsuleDoc.reference)
                                }
                            }
                            
                            batch.commit { error in
                                self.activityIndicator.stopAnimating()
                                if let error = error {
                                    self.errorLabel.text = "Error updating capsules: \(error.localizedDescription)"
                                } else {
                                    self.dismiss(animated: true)
                                }
                            }
                        }
                    }
                }
            }
        }
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
