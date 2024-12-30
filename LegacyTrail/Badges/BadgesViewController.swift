import UIKit
import FirebaseAuth
import FirebaseFirestore
import MapKit

// Structure used to store badge information.
struct Badge {
    let title: String
    let description: String
    let imageName: String
    var percentageComplete: Int
    var progress: String
    
    init(title: String, description: String, imageName: String, percentageComplete: Int = 0, progress: String = "") {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.percentageComplete = percentageComplete
        self.progress = progress
    }
}

// View controller used to display user's badges.
class BadgesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    
    var activityIndicator: UIActivityIndicatorView!
    
    // All badges that can be earned by users.
    var badges: [Badge] = [
        Badge(title: "Capsule Creator", description: "Create your first time capsule", imageName: "archivebox"),
        Badge(title: "Memory Maker", description: "Upload your first memory", imageName: "photo"),
        Badge(title: "Memory Collector", description: "Upload 10 memories", imageName: "tray.full"),
        Badge(title: "Memory Hoarder", description: "Upload 50 memories", imageName: "folder"),
        Badge(title: "Memory Enthusiast", description: "Upload 100 memories", imageName: "square.stack"),
        Badge(title: "Memory Master", description: "Upload 500 memories", imageName: "rectangle.stack"),
        Badge(title: "Long-Term Visionary", description: "Create a time capsule for 20 years in the future", imageName: "calendar.circle"),
        Badge(title: "Half-Century Planner", description: "Create a time capsule for 50 years in the future", imageName: "calendar.badge.clock"),
        Badge(title: "Centennial Dreamer", description: "Create a time capsule for 100 years in the future", imageName: "hourglass"),
        Badge(title: "Local Explorer", description: "Discover 5 locations", imageName: "mappin.and.ellipse"),
        Badge(title: "Regional Adventurer", description: "Discover 10 locations", imageName: "map"),
        Badge(title: "Global Voyager", description: "Discover 50 locations", imageName: "globe"),
        Badge(title: "Capsule Recipient", description: "Receive your first time capsule", imageName: "envelope"),
        Badge(title: "Capsule Collector", description: "Receive 5 time capsules", imageName: "envelope.open"),
        Badge(title: "Capsule Hoarder", description: "Receive 20 time capsules", imageName: "archivebox.fill"),
        Badge(title: "Legacy Builder", description: "Add 5 legacy contacts to a time capsule", imageName: "person.3"),
        Badge(title: "Legacy Visionary", description: "Add 10 legacy contacts to a time capsule", imageName: "person.3.fill")
    ]
    
    // Badges that the user has earned. Populated by looking at user data.
    var earnedBadges: [Badge] = []
    
    // Badges that the user has not earned.
    var notEarnedBadges: [Badge] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BadgeCell.self, forCellReuseIdentifier: "BadgeCell")
        
        // Uses custom font for navigation bar title.
        navigationItem.title = "Badges"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont(name: "PlayfairDisplay-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        // Sets up activity indicator programmatically.
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        // Sets up constraints programmatically.
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchBadges()
    }
    
    // Updates user's earned badges by searching database.
    private func fetchBadges() {
        tableView.isHidden = true
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
        let db = Firestore.firestore()
        let userID = Auth.auth().currentUser?.uid
        
        // Statistics used to determine if user has earned a badge.
        var numMemories = 0
        var numCapsulesMade = 0
        var farthestTimeCapsuleYear = 0
        var numCapsulesReceived = 0
        var mostLegacyContactsAdded = 0
        var locations = Set<MKPolygon>()
        
        let statePolygons = GeoJSONParser.parseStates(from: "us_states") // Used to determine number of locations found.
        
        let group = DispatchGroup()
        
        var currentUsername: String?
        
        group.enter()
        // Count how many time capsules the user is a contact of.
        db.collection("users").whereField("uid", isEqualTo: userID!).getDocuments { snapshot, error in
            if let document = snapshot?.documents.first {
                currentUsername = document.data()["username"] as? String
                db.collection("capsules").whereField("contacts", arrayContains: currentUsername!).getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        numCapsulesReceived = documents.count
                    }
                    group.leave()
                }
            }
        }
        
        group.enter()
        // Count how many memories the user has uploaded.
        db.collection("memories").whereField("uid", isEqualTo: userID!).getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                numMemories = documents.count
                for document in documents {
                    if let location = document["location"] as? GeoPoint {
                        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                        // Uses state polygons to count how many locations user has visited.
                        for state in statePolygons {
                            if self.isLocation(coordinate, inside: state) {
                                locations.insert(state)
                                break
                            }
                        }
                    }
                }
            }
            group.leave()
        }
        
        group.enter()
        // Count how many time capsules the user has created.
        db.collection("capsules").whereField("owner", isEqualTo: userID!).getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                numCapsulesMade = documents.count
                for document in documents {
                    // Finds the farthest date of the time capsule that the user has created.
                    if let scheduledDate = document.data()["scheduledDate"] as? Timestamp {
                        let scheduledYear = Calendar.current.component(.year, from: scheduledDate.dateValue())
                        let currentYear = Calendar.current.component(.year, from: Date())
                        let yearDifference = scheduledYear - currentYear
                        farthestTimeCapsuleYear = max(farthestTimeCapsuleYear, yearDifference)
                    }
                    // Finds the capsule with the most legacy contacts.
                    if let legacyContacts = document.data()["contacts"] as? [String] {
                        mostLegacyContactsAdded = max(mostLegacyContactsAdded, legacyContacts.count)
                    }
                }
            }
            group.leave()
        }
        
        // Once all statistics have been calculated, update earned and not earned badges.
        group.notify(queue: .main) {
            self.earnedBadges.removeAll()
            self.notEarnedBadges.removeAll()
            
            // Compares the user's statistic to the badge's requirement.
            let requirements = [1, 1, 10, 50, 100, 500, 20, 50, 100, 5, 10, 50, 1, 5, 20, 5, 10]
            let statistics = [numCapsulesMade, numMemories, numMemories, numMemories, numMemories, numMemories, farthestTimeCapsuleYear, farthestTimeCapsuleYear, farthestTimeCapsuleYear, locations.count, locations.count, locations.count, numCapsulesReceived, numCapsulesReceived, numCapsulesReceived, mostLegacyContactsAdded, mostLegacyContactsAdded]
            
            for i in 0 ..< self.badges.count {
                self.checkBadges(badge: self.badges[i], requirement: requirements[i], earned: statistics[i])
            }
            
            self.tableView.reloadData()
            self.activityIndicator.stopAnimating()
            self.tableView.isHidden = false
        }
    }
    
    // Checks if a coordinate is within a polygon.
    private func isLocation(_ location: CLLocationCoordinate2D, inside polygon: MKPolygon) -> Bool {
        let renderer = MKPolygonRenderer(polygon: polygon)
        let point = MKMapPoint(location)
        let mapPoint = renderer.point(for: point)
        return renderer.path.contains(mapPoint)
    }
    
    // Checks if a user meets the critera for a badge.
    private func checkBadges(badge: Badge, requirement: Int, earned: Int) {
        var newBadge = badge
        if earned >= requirement {
            newBadge.percentageComplete = 100
            // Adds badge to earned if user meets requirement.
            earnedBadges.append(newBadge)
        } else {
            // Calculates completion percentage.
            newBadge.percentageComplete = Int(Double(earned) / Double(requirement) * 100)
            newBadge.progress = "\(earned)/\(requirement)"
            notEarnedBadges.append(newBadge)
        }
    }
    
    // Table view is divided into two sections.
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    // Earned badges put in top section and unearned badges put in bottom section.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? earnedBadges.count : notEarnedBadges.count
    }
    
    // Does not add section header if no badges.
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && !earnedBadges.isEmpty {
            return "Badges Earned"
        } else if section == 1 && !notEarnedBadges.isEmpty {
            return "Badges Not Yet Earned"
        }
        return nil
    }
    
    // Updates cell with badge information.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BadgeCell", for: indexPath) as! BadgeCell
        let badge = indexPath.section == 0 ? earnedBadges[indexPath.row] : notEarnedBadges[indexPath.row]
        
        cell.selectionStyle = .none
        cell.titleLabel.text = badge.title
        cell.descriptionLabel.text = badge.description
        cell.badgeImage.image = UIImage(systemName: badge.imageName)
        cell.badgeImage.tintColor = indexPath.section == 0 ? .systemBlue : .systemGray
        cell.percentageLabel.text = badge.percentageComplete == 100 ? "" : "\(badge.percentageComplete)%"
        cell.progressLabel.text = badge.progress
        
        return cell
    }
}
