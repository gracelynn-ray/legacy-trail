import UIKit
import FirebaseAuth

// View controller that allows user to log in to account.
class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField! // Text field for email address.
    @IBOutlet weak var passwordTextField: UITextField! // Text field for password.
    @IBOutlet weak var errorLabel: UILabel! // Displays error message.
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        passwordTextField.isSecureTextEntry = true
        
        activityIndicator.hidesWhenStopped = true
        
        emailTextField.layer.cornerRadius = emailTextField.frame.height / 2
        emailTextField.layer.borderWidth = 0.75
        emailTextField.layer.borderColor = UIColor.black.cgColor
        emailTextField.clipsToBounds = true
        
        passwordTextField.layer.cornerRadius = passwordTextField.frame.height / 2
        passwordTextField.layer.borderWidth = 0.75
        passwordTextField.layer.borderColor = UIColor.black.cgColor
        passwordTextField.clipsToBounds = true

        addPadding(to: emailTextField, left: 10, right: 10)
        addPadding(to: passwordTextField, left: 10, right: 10)
    }

    // Helper function to add text field left and right padding.
    private func addPadding(to textField: UITextField, left: CGFloat, right: CGFloat) {
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: textField.frame.height))
        textField.leftView = leftPaddingView
        textField.leftViewMode = .always
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: textField.frame.height))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
    }
    
    // Logs user in when button is pressed. Displays error if error is encountered.
    @IBAction func pressedLoginButton(_ sender: Any) {
        self.errorLabel.text = ""
        activityIndicator.startAnimating()
        Auth.auth().signIn(withEmail: emailTextField.text!, password: passwordTextField.text!) { (result, error) in
            self.activityIndicator.stopAnimating()
            if let error {
                self.errorLabel.text = error.localizedDescription
            } else {
                self.performSegue(withIdentifier: "loginSegue", sender: nil)
                self.errorLabel.text = ""
                self.emailTextField.text = ""
                self.passwordTextField.text = ""
            }
        }
    }
    
    // Takes user to register screen.
    @IBAction func pressedRegisterButton(_ sender: Any) {
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
