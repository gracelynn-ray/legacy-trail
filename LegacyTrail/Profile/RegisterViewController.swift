import UIKit
import FirebaseAuth
import FirebaseFirestore

// View controller that displays user registration details.
class RegisterViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        usernameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        passwordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true
        activityIndicator.hidesWhenStopped = true
        
        emailTextField.layer.cornerRadius = emailTextField.frame.height / 2
        emailTextField.layer.borderWidth = 0.75
        emailTextField.layer.borderColor = UIColor.black.cgColor
        emailTextField.clipsToBounds = true
        
        passwordTextField.layer.cornerRadius = passwordTextField.frame.height / 2
        passwordTextField.layer.borderWidth = 0.75
        passwordTextField.layer.borderColor = UIColor.black.cgColor
        passwordTextField.clipsToBounds = true
        
        usernameTextField.layer.cornerRadius = emailTextField.frame.height / 2
        usernameTextField.layer.borderWidth = 0.75
        usernameTextField.layer.borderColor = UIColor.black.cgColor
        usernameTextField.clipsToBounds = true
        
        confirmPasswordTextField.layer.cornerRadius = passwordTextField.frame.height / 2
        confirmPasswordTextField.layer.borderWidth = 0.75
        confirmPasswordTextField.layer.borderColor = UIColor.black.cgColor
        confirmPasswordTextField.clipsToBounds = true

        addPadding(to: emailTextField, left: 10, right: 10)
        addPadding(to: passwordTextField, left: 10, right: 10)
        addPadding(to: usernameTextField, left: 10, right: 10)
        addPadding(to: confirmPasswordTextField, left: 10, right: 10)
    }

    // Helper function to add left and right padding.
    private func addPadding(to textField: UITextField, left: CGFloat, right: CGFloat) {
        // Left padding view.
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: textField.frame.height))
        textField.leftView = leftPaddingView
        textField.leftViewMode = .always
        
        // Right padding view.
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: textField.frame.height))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
    }

    // Attempts to register user.
    @IBAction func pressedRegisterButton(_ sender: Any) {
        errorLabel.text = ""
        // Tests if any text fields are empty.
        if usernameTextField.text == "" {
            errorLabel.text = "Username field empty."
        } else if emailTextField.text == "" {
            errorLabel.text = "Email field empty."
        } else if passwordTextField.text == "" {
            errorLabel.text = "Password field empty."
        } else if confirmPasswordTextField.text == "" {
            errorLabel.text = "Please confirm password."
        } else if passwordTextField.text != confirmPasswordTextField.text {
            // Checks if password confirmation is correct.
            errorLabel.text = "Passwords do not match."
        } else {
            activityIndicator.startAnimating()
            let username = usernameTextField.text!.lowercased()
                    
            // Checks if the username already exists in Firestore.
            let db = Firestore.firestore()
            db.collection("users").whereField("username", isEqualTo: username).getDocuments { (snapshot, error) in
                if error != nil {
                    self.activityIndicator.stopAnimating()
                    self.errorLabel.text = "Error checking username availability."
                    return
                }
                
                if snapshot?.documents.count ?? 0 > 0 {
                    // Username is already taken
                    self.activityIndicator.stopAnimating()
                    self.errorLabel.text = "Username is already taken."
                } else {
                    // Username is available, proceed with user registration
                    self.registerUser()
                }
            }
        }
    }
    
    private func registerUser() {
        var userData: [String: Any] = [
            "username" : self.usernameTextField.text!.lowercased(),
        ]
        
        Auth.auth().createUser(withEmail: emailTextField.text!, password: passwordTextField.text!) { (result, error) in
            if let error = error {
                self.activityIndicator.stopAnimating()
                self.errorLabel.text = error.localizedDescription
            } else {
                userData["uid"] = result!.user.uid
                
                let db = Firestore.firestore()
                db.collection("users").addDocument(data: userData) { error in
                    if error != nil { return }
                    
                    let preferencesData: [String: Any] = [
                        "ready": true,
                        "received": true,
                        "day": true
                    ]

                    db.collection("preferences").document(result!.user.uid).setData(preferencesData) { error in
                        self.activityIndicator.stopAnimating()

                        if let error = error {
                            self.errorLabel.text = "Error saving notification preferences: \(error.localizedDescription)"
                            return
                        }
                    }
                }
                self.activityIndicator.stopAnimating()
                Auth.auth().signIn(withEmail: self.emailTextField.text!, password: self.passwordTextField.text!)
                self.performSegue(withIdentifier: "registerSegue", sender: nil)
                self.errorLabel.text = ""
                self.emailTextField.text = ""
                self.passwordTextField.text = ""
                self.usernameTextField.text = ""
                self.confirmPasswordTextField.text = ""
            }
        }
    }
    
    // Takes user back to login screen.
    @IBAction func pressedCancelButton(_ sender: Any) {
        self.dismiss(animated: true)
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
