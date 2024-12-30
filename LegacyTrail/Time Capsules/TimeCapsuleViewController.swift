import UIKit
import FirebaseAuth
import FirebaseFirestore

// Holds information for time capsules.
struct TimeCapsule {
    let id: String
    let owner: String
    let ownerUsername: String
    var scheduledDate: String
    var contacts: [String]
    var shareable: Bool
}

// View controller displays received and scheduled time capsules.
class TimeCapsuleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, Updatable {
    
    var scheduledCapsules:[TimeCapsule] = []
    var receivedCapsules:[TimeCapsule] = []
    
    @IBOutlet weak var tableView: UITableView!
    
    var noTimeCapsulesLabel: UILabel!
    
    let scheduledCellIdentifier = "ScheduledTimeCapsuleCell"
    let recievedCellIdentifier = "RecievedTimeCapsuleCell"
    
    let createCapsuleSegueIdentifier = "CreateCapsuleSegue"
    let editCapsuleSegueIdentifier = "EditCapsuleSegue"
    
    var selectedIndex:Int? // Stores index from button tag.
    
    var activityIndicator: UIActivityIndicatorView!
    var username = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        
        navigationItem.title = "Time Capsules"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont(name: "PlayfairDisplay-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        let backButton = UIBarButtonItem()
        backButton.tintColor = .label
        navigationItem.backBarButtonItem = backButton
        
        let plusButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(plusButtonTapped)
        )
        plusButton.tintColor = .label
        navigationItem.rightBarButtonItem = plusButton
        
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        noTimeCapsulesLabel = UILabel()
        noTimeCapsulesLabel.text = "No Time Capsules Found"
        noTimeCapsulesLabel.textColor = .secondaryLabel
        noTimeCapsulesLabel.textAlignment = .center
        noTimeCapsulesLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        noTimeCapsulesLabel.isHidden = true
        noTimeCapsulesLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noTimeCapsulesLabel)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            noTimeCapsulesLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noTimeCapsulesLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 25)
        ])
        
        fetchTimeCapsules()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    @objc func plusButtonTapped() {
        performSegue(withIdentifier: "CreateCapsuleSegue", sender: self)
    }
    
    // Date to string formatter.
    private func formatDate(date: Timestamp) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long // Use .short, .medium, or .full for other formats.
        dateFormatter.timeStyle = .none // No need to display the time in this case.
        return dateFormatter.string(from: date.dateValue())
    }
    
    // String to date formatter.
    func getDateFormat(from dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long // Ensure this matches the date string format.
        dateFormatter.timeStyle = .none // No time component if it's not in the string.
        
        if let date = dateFormatter.date(from: dateString) {
            return date
        } else {
            return nil
        }
    }
    
    // Fetch time capsules based on current user.
    func fetchTimeCapsules() {
        tableView.isHidden = true
        noTimeCapsulesLabel.isHidden = true
        activityIndicator.startAnimating()
        
        let uid = Auth.auth().currentUser?.uid
        let db = Firestore.firestore()
        
        // Get the current user's username.
        func fetchCurrentUserUsername(completion: @escaping (String?) -> Void) {
            db.collection("users").whereField("uid", isEqualTo: uid!).getDocuments { (snapshot, error) in
                if error != nil {
                    completion(nil)
                } else if let snapshot = snapshot, snapshot.documents.count == 1 {
                    let document = snapshot.documents.first!
                    let username = document.data()["username"] as? String ?? ""
                    completion(username)
                } else {
                    completion(nil)
                }
            }
        }
        
        // Fetch time capsules after username is retrieved.
        fetchCurrentUserUsername { currentUserUsername in
            guard let currentUserUsername = currentUserUsername else { return }
            
            var scheduledCapsules: [TimeCapsule] = []
            var receivedCapsules: [TimeCapsule] = []
            
            // Fetch scheduled time capsules.
            db.collection("capsules").whereField("owner", isEqualTo: uid!).order(by: "scheduledDate").getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching capsules owned by user: \(error.localizedDescription)")
                } else if let snapshot = snapshot {
                    for document in snapshot.documents {
                        let data = document.data()
                        let id = document.documentID
                        let scheduledDate = self.formatDate(date: data["scheduledDate"] as! Timestamp)
                        let contacts = data["contacts"] as? [String] ?? []
                        let shareable = data["shareable"] as? Bool ?? true
                        let capsule = TimeCapsule(id: id, owner: uid!, ownerUsername: currentUserUsername, scheduledDate: scheduledDate, contacts: contacts, shareable: shareable)
                        scheduledCapsules.append(capsule)
                    }
                }
            }
            
            self.username = currentUserUsername
            
            // Fetch received time capsules.
            db.collection("capsules").whereField("contacts", arrayContains: currentUserUsername)
                .order(by: "scheduledDate").getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching received capsules: \(error.localizedDescription)")
                } else if let snapshot = snapshot {
                    let dispatchGroup = DispatchGroup() // Handle nested queries for owner username.
                    
                    for document in snapshot.documents {
                        let data = document.data()
                        let id = document.documentID
                        let ownerID = data["owner"] as? String ?? ""
                        let scheduleDate = self.formatDate(date: data["scheduledDate"] as! Timestamp)
                        let contacts = data["contacts"] as? [String] ?? []
                        let shareable = data["shareable"] as? Bool ?? true
                        
                        // Fetch the username of each capsule owner.
                        dispatchGroup.enter()
                        db.collection("users").whereField("uid", isEqualTo: ownerID).getDocuments { (snapshot, error) in
                            var ownerUsername = ""
                            if let snapshot = snapshot, snapshot.documents.count == 1 {
                                let userDocument = snapshot.documents.first!
                                ownerUsername = userDocument.data()["username"] as? String ?? ""
                            }
                            
                            let capsule = TimeCapsule(id: id, owner: ownerID, ownerUsername: ownerUsername, scheduledDate: scheduleDate, contacts: contacts, shareable: shareable)
                            receivedCapsules.append(capsule)
                            dispatchGroup.leave()
                        }
                    }
                    
                    dispatchGroup.notify(queue: .main) {
                        // Update the user interface after all received capsules are fetched.
                        self.scheduledCapsules = scheduledCapsules
                        self.receivedCapsules = receivedCapsules
                        self.noTimeCapsulesLabel.isHidden = !(scheduledCapsules.isEmpty && receivedCapsules.isEmpty)
                        self.tableView.isHidden = scheduledCapsules.isEmpty && receivedCapsules.isEmpty
                        self.activityIndicator.stopAnimating()
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    // Returns the number of sections in table view.
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    // Returns the title for sections in table view.
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && !scheduledCapsules.isEmpty {
            return "Scheduled Time Capsules"
        } else if section == 1 && !receivedCapsules.isEmpty {
            return "Received Time Capsules"
        }
        return nil
    }
    
    // Returns height for cell.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    // Returns number of rows in specific section.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return scheduledCapsules.count
        } else {
            return receivedCapsules.count
        }
    }
    
    // Returns cell depending on section.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: scheduledCellIdentifier, for: indexPath) as! ScheduledTimeCapsuleTableViewCell
            
            cell.dateLabel?.text = scheduledCapsules[indexPath.row].scheduledDate
            cell.editButton.tag = indexPath.row
            cell.deleteButton.tag = indexPath.row
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: recievedCellIdentifier, for: indexPath) as! RecievedTimeCapsuleTableViewCell
            cell.senderLabel?.text = "\(receivedCapsules[indexPath.row].ownerUsername)'s capsule"
            let currentDate = Date()
            if let scheduleDate = getDateFormat(from: receivedCapsules[indexPath.row].scheduledDate) {
                if scheduleDate > currentDate { // Schedule date not yet reached, hide view button and display label.
                    cell.viewButton?.isHidden = true
                    cell.mapButton?.isHidden = true
                    cell.availableLabel?.isHidden = false
                    cell.availableLabel.text = "Available on \n\(receivedCapsules[indexPath.row].scheduledDate)"
                } else { // Display view button.
                    cell.viewButton?.isHidden = false
                    cell.mapButton?.isHidden = false
                    cell.availableLabel?.isHidden = true
                }
            }
            cell.viewButton.tag = indexPath.row
            cell.mapButton.tag = indexPath.row
            cell.selectionStyle = .none
            return cell
        }
    }
    
    // When user selects a cells, deselects so cell does not stay gray.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == 1 {
            let leaveAction = UIContextualAction(style: .destructive, title: "Leave") { (action, view, completionHandler) in
                let capsule = self.receivedCapsules[indexPath.row]
                self.removeUserFromTimeCapsule(capsule: capsule) {
                    self.update(newTitle: "", newDescription: "")
                    completionHandler(true)
                }
            }
            leaveAction.backgroundColor = .systemRed
            return UISwipeActionsConfiguration(actions: [leaveAction])
        }
        return nil
    }
    
    func removeUserFromTimeCapsule(capsule: TimeCapsule, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else {
            completion()
            return
        }

        db.collection("users").whereField("uid", isEqualTo: uid).getDocuments { (snapshot, error) in
            if error != nil {
                completion()
                return
            }
            
            guard let snapshot = snapshot, let document = snapshot.documents.first,
                  let username = document.data()["username"] as? String else {
                completion()
                return
            }

            let capsuleRef = db.collection("capsules").document(capsule.id)
            capsuleRef.getDocument { (document, error) in
                if error != nil {
                    completion()
                    return
                }
                
                guard document != nil else {
                    completion()
                    return
                }

                capsuleRef.updateData([
                    "contacts": FieldValue.arrayRemove([username])
                ]) { error in
                    if let error = error {
                        print("Error removing user from contacts: \(error.localizedDescription)")
                    }
                    completion()
                }
            }
        }
    }
    
    @IBAction func pressedEditButton(_ sender: UIButton) {
        selectedIndex = sender.tag
        performSegue(withIdentifier: editCapsuleSegueIdentifier, sender: self)
    }
    
    // Deletes capsule document from database. Uses index stored in button's tag to get correct time capsule.
    @IBAction func pressedDeleteButton(_ sender: UIButton) {
        let alert = UIAlertController(title: "Delete Capsule", message: "Are you sure you want to delete your time capsule? This action cannot be undone.", preferredStyle: .alert)
                
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
            let index = sender.tag
            let documentId = self.scheduledCapsules[index].id
            let db = Firestore.firestore()
            
            db.collection("capsules").document(documentId).delete() { error in
                if let error = error {
                    print("Error deleting capsule: \(error.localizedDescription)")
                } else {
                    print("Sucessfully deleted capsule.")
                }
            }
            self.update(newTitle: "", newDescription: "") // Refresh time capsules.
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func pressedMapButton(_ sender: Any) {
        if let button = sender as? UIButton {
            selectedIndex = button.tag
            performSegue(withIdentifier: "MapSegue", sender: self)
        }
    }
    
    @IBAction func pressedViewButton(_ sender: Any) {
        if let button = sender as? UIButton {
            selectedIndex = button.tag
            performSegue(withIdentifier: "MemoriesSegue", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "MemoriesSegue",
            let nextVC = segue.destination as? MemoriesViewController,
            let index = selectedIndex {
            nextVC.isOwner = false
            nextVC.userId = receivedCapsules[index].owner
            nextVC.date = getDateFormat(from: receivedCapsules[index].scheduledDate)
            nextVC.isShareable = receivedCapsules[index].shareable
        } else if segue.identifier == "MapSegue",
            let nextVC = segue.destination as? ContactMap,
            let index = selectedIndex {
            nextVC.userId = receivedCapsules[index].owner
            nextVC.date = getDateFormat(from: receivedCapsules[index].scheduledDate)
            nextVC.isShareable = receivedCapsules[index].shareable
        } else if segue.identifier == createCapsuleSegueIdentifier,
            let nextVC = segue.destination as? CreateEditCapsuleViewController {
            nextVC.createMode = true
            nextVC.delegate = self as Updatable
            nextVC.capsule = TimeCapsule(id: "", owner: "", ownerUsername: username, scheduledDate: "", contacts: [], shareable: true)
        } else if segue.identifier == editCapsuleSegueIdentifier,
            let nextVC = segue.destination as? CreateEditCapsuleViewController {
            nextVC.createMode = false
            if let index = selectedIndex {
                nextVC.capsule = scheduledCapsules[index]
            }
            nextVC.delegate = self as Updatable
        }
    }
    
    func update(newTitle: String, newDescription: String) {
        noTimeCapsulesLabel.isHidden = true
        fetchTimeCapsules()
    }
}
