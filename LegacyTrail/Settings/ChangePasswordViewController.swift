import UIKit
import FirebaseAuth

// View controller that displays password change.
class ChangePasswordViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var newPasswordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.hidesWhenStopped = true
        newPasswordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true
        newPasswordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        
        newPasswordTextField.layer.cornerRadius = newPasswordTextField.frame.height / 2
        newPasswordTextField.layer.borderWidth = 0.75
        newPasswordTextField.layer.borderColor = UIColor.black.cgColor
        newPasswordTextField.clipsToBounds = true

        addPadding(to: newPasswordTextField, left: 10, right: 10)
        
        confirmPasswordTextField.layer.cornerRadius = confirmPasswordTextField.frame.height / 2
        confirmPasswordTextField.layer.borderWidth = 0.75
        confirmPasswordTextField.layer.borderColor = UIColor.black.cgColor
        confirmPasswordTextField.clipsToBounds = true

        addPadding(to: confirmPasswordTextField, left: 10, right: 10)
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
    
    // Attemps to change password.
    @IBAction func saveButtonPressed(_ sender: Any) {
        guard let newPassword = newPasswordTextField.text, !newPassword.isEmpty else {
            errorLabel.text = "Please enter a new password."
            return
        }
        
        guard let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            errorLabel.text = "Please confirm your new password."
            return
        }
        
        // Check if the new password and confirmation password match.
        guard newPassword == confirmPassword else {
            errorLabel.text = "Passwords do not match."
            return
        }
        
        activityIndicator.startAnimating()
        errorLabel.text = nil
        
        // Changes password used to login to Firebase.
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            self.activityIndicator.stopAnimating()
            if let error {
                self.errorLabel.text = error.localizedDescription
            } else {
                self.newPasswordTextField.text = ""
                self.confirmPasswordTextField.text = ""
                self.newPasswordTextField.resignFirstResponder()
                self.confirmPasswordTextField.resignFirstResponder()
                self.errorLabel.text = "Password changed successfully."
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
