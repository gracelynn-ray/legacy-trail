import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateEditCapsuleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    var createMode:Bool! // Denotes if user is creating a new capsule or editing existing one.
    var capsule = TimeCapsule(id: "", owner: "", ownerUsername: "", scheduledDate: "", contacts: [], shareable: true)
    var delegate: Updatable!
    
    var searchResults: [String] = []
    var allUsernames: [String] = []
    var noResults = false
    
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var contactTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var shareMemories: UISwitch!
    
    var datePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        contactTextField.delegate = self
        
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont(name: "PlayfairDisplay-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        let doneButton = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .plain,
            target: self,
            action: #selector(doneButtonTapped)
        )
        doneButton.tintColor = .label
        navigationItem.rightBarButtonItem = doneButton
        
        // Set up date picker programmatically.
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.addTarget(self, action: #selector(dateChange(datePicker:)), for: UIControl.Event.valueChanged)
        datePicker.frame.size = CGSize(width: 0, height: 300)
        datePicker.preferredDatePickerStyle = .wheels
        
        dateTextField.inputView = datePicker
        dateTextField.text = capsule.scheduledDate == "" ? formatDate(date: Date()) : capsule.scheduledDate
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tapGesture)
        
        dateTextField.layer.cornerRadius = dateTextField.frame.height / 2
        dateTextField.layer.borderWidth = 0.75
        dateTextField.layer.borderColor = UIColor.label.cgColor
        dateTextField.clipsToBounds = true
        
        contactTextField.layer.cornerRadius = contactTextField.frame.height / 2
        contactTextField.layer.borderWidth = 0.75
        contactTextField.layer.borderColor = UIColor.label.cgColor
        contactTextField.clipsToBounds = true
        
        addPadding(to: dateTextField, left: 10, right: 10)
        addPadding(to: contactTextField, left: 10, right: 10)
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
    
    // Updates date text field when date picker changes value.
    @objc func dateChange(datePicker: UIDatePicker) {
        dateTextField.text = formatDate(date: datePicker.date)
    }
    
    // Takes date format and converts to String.
    func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func getDateFormat(from dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long // Ensure this matches the date string format.
        dateFormatter.timeStyle = .none // No time component if it is not in the string.
        
        if let date = dateFormatter.date(from: dateString) {
            return date
        } else {
            return nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if createMode == true { // Create capsule mode.
            navigationItem.title = "Create Capsule"
            capsule.contacts = []
        } else { // Edit existing capsule mode.
            navigationItem.title = "Edit Capsule"
            // Retrieve existing date picked.
            datePicker.date = getDateFormat(from: capsule.scheduledDate)!
            shareMemories.isOn = capsule.shareable
        }
        
        // Load all usernames in database.
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if error != nil { return }
            guard let documents = snapshot?.documents else { return }
            self.allUsernames = documents.compactMap { $0.data()["username"] as? String }
        }
    }
    
    // Saves new capsule or saves changes to existing capsule.
    @objc func doneButtonTapped() {
        if createMode == true {
            let capsule: [String:Any] = [
                "contacts": capsule.contacts,
                "scheduledDate": datePicker.date, // Storing date type into timestamp into database.
                "owner": Auth.auth().currentUser!.uid,
                "shareable": shareMemories.isOn
            ]
            let db = Firestore.firestore()
            db.collection("capsules").addDocument(data: capsule) { error in
                if error != nil { return }
            }
            // Reload data.
            let otherVC = self.delegate!
            otherVC.update(newTitle: "", newDescription: "")
            navigationController?.popViewController(animated: true)
        } else {
            let db = Firestore.firestore()
            
            db.collection("capsules").document(capsule.id).updateData([
                "contacts": capsule.contacts,
                "scheduledDate": datePicker.date, // Storing date type into timestamp into database.
                "shareable": shareMemories.isOn
            ]) { error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                }
            }
            // Reload data.
            let otherVC = self.delegate!
            otherVC.update(newTitle: "", newDescription: "")
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func deleteContactButton(_ sender: UIButton) {
        let index = sender.tag

        if index < searchResults.count {
            // Add the selected user from search results to the contacts.
            capsule.contacts.append(searchResults.remove(at: index - (noResults ? 1 : 0)))
            tableView.reloadData()
        } else {
            // Remove the user from contacts
            let contactIndex = index - searchResults.count - (noResults ? 1 : 0)
            capsule.contacts.remove(at: contactIndex)
            tableView.reloadData()
        }
    }
    
    // MARK: table view functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return capsule.contacts.count + searchResults.count + (noResults ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LegacyContactCell") as! LegacyContactTableViewCell
        cell.selectionStyle = .none
        cell.deleteButton.tag = indexPath.row

        if noResults && indexPath.row == 0 { // Show "User not found" at the top if no search results.
            cell.userLabel.text = "User not found."
            cell.userLabel.textColor = .lightGray
            cell.deleteButton.isHidden = true
        } else if indexPath.row < searchResults.count { // Show search results.
            cell.userLabel.text = searchResults[indexPath.row - (noResults ? 1 : 0)]
            cell.deleteButton.setImage(UIImage(systemName: "plus"), for: .normal)
            cell.userLabel.textColor = .label
            cell.deleteButton.isHidden = false
        } else { // Show contacts after search results.
            let contactIndex = indexPath.row - searchResults.count - (noResults ? 1 : 0)
            cell.userLabel.text = capsule.contacts[contactIndex]
            cell.deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
            cell.userLabel.textColor = .label
            cell.deleteButton.isHidden = false
        }

        return cell
    }
    
    // Boiler plate code for dismissing keyboard when background is touched.
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // Method to dismiss the keyboard.
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        
        // Combine the current text with the replacement string.
        let searchText = (text as NSString).replacingCharacters(in: range, with: string).lowercased()
        
        // Update searchResults based on the searchText.
        if searchText.isEmpty {
            noResults = false
            searchResults = []
        } else {
            noResults = false
            searchResults = allUsernames.filter { $0.contains(searchText) && !capsule.contacts.contains($0) && $0 != capsule.ownerUsername }
            if searchResults.count == 0 {
                noResults = true
            }
        }
        
        tableView.reloadData()
        return true
    }
}
