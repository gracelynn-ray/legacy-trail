import UIKit
import FirebaseFirestore

// View controller that displays memory edit form.
class MemoryEditViewController: UIViewController, UITextFieldDelegate {

    let titleField = UITextField()
    let dateLabel = UILabel()
    let imageView = UIImageView()
    let descriptionField = UITextView()
    let saveButton = UIButton(type: .system)
    
    // Memory that is being edited. Passed in from detail screen.
    var memory = Memory(id: "", title: "", description: "", date: "", timestamp: Timestamp(), image: UIImage())

    var delegate: Updatable!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleField.delegate = self
        
        // Creates views and setes up UI programmatically.
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
        
        saveButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        saveButton.tintColor = .white
        saveButton.backgroundColor = UIColor.darkGray
        saveButton.layer.cornerRadius = 25
        saveButton.clipsToBounds = true
        saveButton.layer.shadowColor = UIColor.black.cgColor
        saveButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        saveButton.layer.shadowRadius = 5
        saveButton.layer.shadowOpacity = 0.2
        saveButton.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
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
            
            saveButton.widthAnchor.constraint(equalToConstant: 50),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        titleField.text = memory.title
        dateLabel.text = memory.date
        imageView.image = memory.image
        descriptionField.text = memory.description
    }

    // Updates the memory details in database when user presses save.
    @objc func saveButtonPressed() {
        let db = Firestore.firestore()
        
        db.collection("memories").document(memory.id).updateData([
            "title": titleField.text!,
            "description": descriptionField.text!
        ]) { error in
            if let error = error {
                print("Error updating document: \(error.localizedDescription)")
            } else {
                print("Document successfully updated!")
                let otherVC = self.delegate!
                otherVC.update(newTitle: self.titleField.text!, newDescription: self.descriptionField.text!)
                self.dismiss(animated: true)
            }
        }
    }
    
    // Dismissing keyboard on return
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    func setRightPaddingPoints(_ amount:CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}
