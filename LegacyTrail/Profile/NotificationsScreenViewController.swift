import UIKit
import SDWebImage
import FirebaseAuth
import FirebaseFirestore

// Holds information for notifications.
struct Notification {
    let id: String
    let title: String
    let description: String
    var read: Bool
    let type: Int
    let selectedMemory: String?
    let timestamp: Timestamp
}

// View controller that displays all of user's notifications.
class NotificationsScreenViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var notifications: [Notification] = []
    
    @IBOutlet weak var tableView: UITableView!

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let noNotificationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Notifications"
        label.textAlignment = .center
        label.textColor = .gray
        label.isHidden = true
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(NotificationTableViewCell.self, forCellReuseIdentifier: "NotificationCell")
        
        let backButton = UIBarButtonItem()
        backButton.tintColor = .label
        navigationItem.backBarButtonItem = backButton
        
        navigationItem.title = "Notifications"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont(name: "PlayfairDisplay-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        // Sets up elements programmatically.
        setupActivityIndicator()
        setupNoNotificationsLabel()
        
        fetchNotifications()
    }
    
    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupNoNotificationsLabel() {
        noNotificationsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noNotificationsLabel)
        
        NSLayoutConstraint.activate([
            noNotificationsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noNotificationsLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // Pulls up all of user's notifications.
    private func fetchNotifications() {
        noNotificationsLabel.isHidden = true
        activityIndicator.startAnimating()

        let userId = Auth.auth().currentUser!.uid
        
        let db = Firestore.firestore()
        db.collection("notifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if error != nil { return }

                self.notifications.removeAll()
                                
                for document in snapshot!.documents {
                    let data = document.data()
                    let id = document.documentID
                    let title = data["title"] as? String ?? ""
                    let description = data["description"] as? String ?? ""
                    let type = data["type"] as? Int ?? 0
                    let read = data["read"] as? Bool ?? false
                    let selectedMemory = data["selectedMemory"] as? String
                    let date = data["timestamp"] as? Timestamp ?? Timestamp()
                    let notif = Notification(id: id, title: title, description: description, read: read, type: type, selectedMemory: selectedMemory, timestamp: date)
                    self.notifications.append(notif)
                }
            
                DispatchQueue.main.async {
                    if self.notifications.isEmpty {
                        self.noNotificationsLabel.isHidden = false
                    }
                    self.activityIndicator.stopAnimating()
                    self.tableView.reloadData()
                }
        }
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as? NotificationTableViewCell else {
            return UITableViewCell()
        }
        
        let notification = notifications[indexPath.row]
        cell.configure(with: notification)
        return cell
    }
    
    // Reads notifications when user taps on it.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let notification = notifications[indexPath.row]
        
        if !notification.read {
            Firestore.firestore()
                .collection("notifications")
                .document(notification.id)
                .updateData(["read": true]) { error in
                    if error != nil { return }
                    
                    self.notifications[indexPath.row].read = true
                    
                    DispatchQueue.main.async {
                        tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
        }
        
        // Segues to another screen for certain notification types.
        switch notification.type {
        case 2:
            guard let memoryId = notification.selectedMemory else { return }
            loadMemoryDataAndSegue(memoryId: memoryId)
        case 1:
            performSegue(withIdentifier: "TimeCapsuleSegue", sender: self)
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // Pulls up memory details for "on this day" reminders.
    private func loadMemoryDataAndSegue(memoryId: String) {
        let db = Firestore.firestore()
        db.collection("memories").document(memoryId).getDocument { (document, error) in
            if error != nil { return }
            guard let document = document, document.exists else { return }

            let data = document.data()!
            let title = data["title"] as? String ?? ""
            let description = data["description"] as? String ?? ""
            var date = ""
            var timestamp: Timestamp?

            if let ts = data["date"] as? Timestamp {
                timestamp = ts
                date = self.formatDate(date: ts)
            }

            if let imageURLString = data["imageURL"] as? String, let imageURL = URL(string: imageURLString) {
                  SDWebImageDownloader.shared.downloadImage(with: imageURL) { (downloadedImage, _, _, _) in
                    let image = downloadedImage ?? UIImage(named: "unavailable")
                    let memory = Memory(id: document.documentID, title: title, description: description, date: date, timestamp: timestamp, image: image!)
                    self.performSegue(withIdentifier: "DetailSegue", sender: memory)
                }
            } else {
                let memory = Memory(id: document.documentID, title: title, description: description, date: date, timestamp: timestamp, image: UIImage(named: "unavailable")!)
                self.performSegue(withIdentifier: "DetailSegue", sender: memory)
            }
        }
    }
    
    private func formatDate(date: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date.dateValue())
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DetailSegue",
           let detailsVC = segue.destination as? MemoryDetailViewController,
           let memory = sender as? Memory {
            detailsVC.isOwner = false
            detailsVC.memory = memory
        }
    }
}
