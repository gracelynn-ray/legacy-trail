import UIKit
import FirebaseAuth

// View controller that displays option to change user's email.
class ChangeEmailViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var newEmailTextField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.isHidden = true
        activityIndicator.hidesWhenStopped = true
        newEmailTextField.delegate = self
        
        newEmailTextField.layer.cornerRadius = newEmailTextField.frame.height / 2
        newEmailTextField.layer.borderWidth = 0.75
        newEmailTextField.layer.borderColor = UIColor.black.cgColor
        newEmailTextField.clipsToBounds = true

        addPadding(to: newEmailTextField, left: 10, right: 10)
    }

    // Helper function to add left and right padding to text field.
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
    
    // Attemps to change user email to new email.
    @IBAction func saveButtonPressed(_ sender: Any) {
        errorLabel.text = ""
        guard let newEmail = newEmailTextField.text, !newEmail.isEmpty else {
            errorLabel.text = "Please enter a new email address."
            return
        }
        
        // User needs to enter password to verify identity before changing email.
        let alertController = UIAlertController(title: "Verification", message: "Please enter your password to confirm changes.", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            guard let self = self,
                  let password = alertController.textFields?.first?.text,
                  let currentUser = Auth.auth().currentUser,
                  let currentEmail = currentUser.email else {
                return
            }
            
            activityIndicator.startAnimating()
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: password)
            currentUser.reauthenticate(with: credential) { authResult, error in
                if let error = error {
                    self.activityIndicator.stopAnimating()
                    self.errorLabel.text = "Verification failed: \(error.localizedDescription)"
                } else {
                    // Sends email to new email to verify email change.
                    currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                        self.activityIndicator.stopAnimating()
                        if let error = error {
                            self.errorLabel.text = "Error updating email: \(error.localizedDescription)"
                        } else {
                            self.newEmailTextField.text = ""
                            self.errorLabel.text = "Verification email sent! Please check your inbox to confirm the new email."
                        }
                    }
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
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
