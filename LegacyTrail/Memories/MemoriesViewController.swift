import UIKit
import SDWebImage
import FirebaseFirestore
import FirebaseAuth

// Holds memory data.
struct Memory {
    let id: String
    var title: String
    var description: String
    let date: String
    let timestamp: Timestamp?
    let image: UIImage
}

// View controller that displays all of user's memories in a collection view.
class MemoriesViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, Updatable, Deletable {
    
    var memories: [Memory] = []
    var collectionView: UICollectionView!
    var noMemoriesLabel: UILabel!
    var selectedIndexPath: IndexPath?
    
    var isOwner = true // isOwner designates if this memories are being viewed by its owner or a legacy contact.
    var userId = "" // The userId of the memories we want to view.
    var date: Date! // Displays all memories before this date. If a user is viewing its own memories, this date is the current date.
    var activityIndicator: UIActivityIndicatorView!
    var isShareable = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Memories"
        
        navigationItem.title = "Memories"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont(name: "PlayfairDisplay-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        let theme = UserDefaults.standard.string(forKey: "theme") ?? "light"
            
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        // Sets up screen programmatically.
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = theme == "light" ? .tertiarySystemGroupedBackground : .black
        collectionView.register(MemoriesCollectionViewCell.self, forCellWithReuseIdentifier: "MemoryCell")
        view.addSubview(collectionView)
        
        noMemoriesLabel = UILabel()
        noMemoriesLabel.text = "No Memories Found"
        noMemoriesLabel.textAlignment = .center
        noMemoriesLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        noMemoriesLabel.textColor = .secondaryLabel // Dynamic system color
        noMemoriesLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noMemoriesLabel)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        noMemoriesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Sets up constraints programmatically
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            noMemoriesLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noMemoriesLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Anytime memories screen is selected, updates the collection view so that new memories are shown.
        fetchMemories()
    }
    
    // Grabs memories associated with user. Sorts them in chronological order.
    private func fetchMemories() {
        collectionView.isHidden = true
        noMemoriesLabel.isHidden = true
        activityIndicator.isHidden = false
        
        // Shows loading symbol while memories are fetched and downloaded.
        activityIndicator.startAnimating()
        
        let db = Firestore.firestore()
        
        // Grabs memories before the cut off date. Cut off date used for time capsules.
        db.collection("memories")
                .whereField("uid", isEqualTo: userId)
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!)).getDocuments { (snapshot, error) in
            if error != nil { return }
            
            self.memories.removeAll()
            
            // DispatchGroup ensures that everything is finished being fetched before displaying.
            let group = DispatchGroup()
            
            for document in snapshot!.documents {
                let data = document.data()
                let id = document.documentID
                let title = data["title"] as? String ?? ""
                let description = data["description"] as? String ?? ""
                var date = ""
                var timestamp: Timestamp?
                
                if let ts = data["date"] as? Timestamp {
                    timestamp = ts
                    date = self.formatDate(date: ts)
                }
                
                var image = UIImage(named: "unavailable")
                
                if let imageURL = URL(string: data["imageURL"] as? String ?? "") {
                    group.enter()
                    
                    // URL of image is stored in database. Must download the image.
                    SDWebImageDownloader.shared.downloadImage(with: imageURL) { (downloadedImage, _, _, _) in
                        if let downloadedImage = downloadedImage {
                            image = downloadedImage
                        }
                        
                        let memory = Memory(id: id, title: title, description: description, date: date, timestamp: timestamp, image: image!)
                        self.memories.append(memory)
                        
                        group.leave()
                    }
                } else {
                    let memory = Memory(id: id, title: title, description: description, date: date, timestamp: timestamp, image: image!)
                    self.memories.append(memory)
                }
            }
            
            group.notify(queue: .main) {
                
                // Sorts images in chronological order.
                self.memories.sort(by: { (memory1, memory2) -> Bool in
                    if let timestamp1 = memory1.timestamp, let timestamp2 = memory2.timestamp {
                        return timestamp1.dateValue() < timestamp2.dateValue()
                    } else if memory1.timestamp == nil {
                        return false
                    } else {
                        return true
                    }
                })
                
                self.collectionView.reloadData()
                self.activityIndicator.stopAnimating()
                
                // Displays no memories label if user has not created any memories.
                if self.memories.isEmpty {
                    self.collectionView.isHidden = true
                    self.noMemoriesLabel.isHidden = false
                } else {
                    self.collectionView.isHidden = false
                    self.noMemoriesLabel.isHidden = true
                }
            }
        }
    }
    
    // Used to get the date from a timestamp.
    private func formatDate(date: Timestamp) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date.dateValue())
    }
    
    // The number of memories made by this user.
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return memories.count
    }
    
    // Uses custom collection view cell to display each memory. Each memory contains image, title, description, and date.
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MemoryCell", for: indexPath) as! MemoriesCollectionViewCell
        
        let memory = memories[indexPath.row]
        
        cell.imageView.image = memory.image
        cell.title.text = memory.title
        cell.memoryDescription.text = memory.description
        cell.memoryDate.text = memory.date
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = collectionView.frame.size.width - 20
        let cellHeight = memories[indexPath.row].title == "" ? CGFloat(260) : CGFloat(290)
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    // Displays the detail when a memory is selected.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndexPath = indexPath
        performSegue(withIdentifier: "DetailSegue", sender: self)
    }
    
    // Sends the needed information to the details view controller.
    override func prepare(for segue:UIStoryboardSegue, sender:Any?) {
        if segue.identifier == "DetailSegue",
           let nextVC = segue.destination as? MemoryDetailViewController {
            let newMemory = memories[selectedIndexPath!.row]
            nextVC.memory = newMemory
            nextVC.isOwner = self.isOwner
            nextVC.delegate = self
            nextVC.isShareable = self.isShareable
        }
    }
    
    // When memories are edited, updates the collection view.
    func update(newTitle: String, newDescription: String) {
        fetchMemories()
    }
    
    // When memories are deleted, updates the collection view.
    func delete() {
        fetchMemories()
    }
}
