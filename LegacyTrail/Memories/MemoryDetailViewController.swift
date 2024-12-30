import UIKit
import FirebaseStorage
import FirebaseFirestore

protocol Updatable {
    func update(newTitle: String, newDescription: String)
}

protocol Deletable {
    func delete()
}

// View controller that displays details of selected memory.
class MemoryDetailViewController: UIViewController, Updatable {

    let scrollView = UIScrollView()
    let contentView = UIView()

    let memoryTitle = UILabel()
    let memoryDate = UILabel()
    let memoryImage = UIImageView()
    let memoryDescription = UILabel()
    
    let editButton = UIButton(type: .system)
    let deleteButton = UIButton(type: .system)
    let shareButton = UIButton(type: .system)
    
    // Memory being viewed. Passed in when user taps a memory from the memories view screen.
    var memory = Memory(id: "", title: "", description: "", date: "", timestamp: Timestamp(), image: UIImage())
    
    // isOwner used to distinguish user viewing their own memory and legacy contact viewing a time capsule.
    var isOwner = true
    var delegate: UIViewController!
    var isShareable = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Sets up the screen programmatically.
        setupContentView()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupContentView() {
        memoryImage.contentMode = .scaleAspectFit
        memoryImage.layer.cornerRadius = 15
        memoryImage.clipsToBounds = true
        memoryImage.layer.shadowColor = UIColor.black.cgColor
        memoryImage.layer.shadowOpacity = 0.3
        memoryImage.layer.shadowOffset = CGSize(width: 0, height: 5)
        memoryImage.layer.shadowRadius = 8
        memoryImage.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(memoryImage)

        memoryTitle.font = UIFont(name: "PlayfairDisplay-Regular", size: 24)
        memoryTitle.textColor = .label
        memoryTitle.textAlignment = .center
        memoryTitle.translatesAutoresizingMaskIntoConstraints = false
        memoryTitle.numberOfLines = 0
        contentView.addSubview(memoryTitle)
        
        memoryDate.font = UIFont(name: "Avenir Light", size: 14)
        memoryDate.textColor = .secondaryLabel
        memoryDate.textAlignment = .center
        memoryDate.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(memoryDate)

        memoryDescription.font = UIFont(name: "Avenir Next Medium", size: 16)
        memoryDescription.textColor = .label
        memoryDescription.numberOfLines = 0
        memoryDescription.textAlignment = .center
        memoryDescription.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(memoryDescription)

        if isOwner {
            configureButton(button: editButton, image: "square.and.pencil", backgroundColor: .systemBlue, action: #selector(editButtonPressed))
            configureButton(button: deleteButton, image: "trash", backgroundColor: .systemRed, action: #selector(deleteButtonPressed))
        }
        if isShareable {
            configureButton(button: shareButton, image: "square.and.arrow.up", backgroundColor: .label, action: #selector(shareButtonPressed))
        }
        
        let buttonStackView = isOwner ? UIStackView(arrangedSubviews: [editButton, deleteButton, shareButton]) : UIStackView(arrangedSubviews: [shareButton])
        buttonStackView.axis = .horizontal
        buttonStackView.alignment = .center
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 20
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStackView)

        NSLayoutConstraint.activate([
            memoryImage.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            memoryImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            memoryImage.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            // Adjusts height based on aspect ratio of image. Allows image to be seen in full screen.
            memoryImage.heightAnchor.constraint(equalTo: memoryImage.widthAnchor, multiplier: memory.image.size.height / memory.image.size.width),
            
            memoryTitle.topAnchor.constraint(equalTo: memoryImage.bottomAnchor, constant: 20),
            memoryTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            memoryTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            memoryDate.topAnchor.constraint(equalTo: memoryTitle.bottomAnchor, constant: 5),
            memoryDate.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            memoryDescription.topAnchor.constraint(equalTo: memoryDate.bottomAnchor, constant: 10),
            memoryDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            memoryDescription.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            buttonStackView.topAnchor.constraint(equalTo: memoryDescription.bottomAnchor, constant: 25),
            buttonStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonStackView.heightAnchor.constraint(equalToConstant: 50),
            buttonStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        memoryTitle.text = memory.title
        memoryDescription.text = memory.description
        memoryDate.text = memory.date
        memoryImage.image = memory.image
    }
    
    // Sets up the button programmatically.
    private func configureButton(button: UIButton, image: String, backgroundColor: UIColor, action: Selector) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: image)
        config.imagePadding = 0
        config.baseBackgroundColor = .systemGray5
        config.baseForegroundColor = backgroundColor
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        button.configuration = config
        button.backgroundColor = .systemGray5
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc func editButtonPressed() {
        performSegue(withIdentifier: "EditSegue", sender: self)
    }
    
    @objc func deleteButtonPressed() {
        let controller = UIAlertController(
            title: "Delete Memory",
            message: "This memory will be permanently deleted.",
            preferredStyle: .actionSheet
        )
        controller.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel
        ))
        controller.addAction(UIAlertAction(
            title: "Delete",
            style: .destructive) { _ in
                let db = Firestore.firestore()
                let memory = db.collection("memories").document(self.memory.id)
                
                // When memory is deleted, deletes the image in storage and the memory details in database.
                memory.getDocument { document, error in
                    if let document = document, document.exists {
                        if let imagePath = document.get("imagePath") as? String {
                            // Uses the stored image path to delete the image from storage.
                            let storageRef = Storage.storage().reference().child(imagePath)
                            storageRef.delete { error in
                                if let error = error {
                                    print("Error deleting image from storage: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        // Deletes the memory itself from the database.
                        memory.delete { error in
                            if let error = error {
                                print("Error deleting document: \(error.localizedDescription)")
                            } else {
                                if let delegate = self.delegate as? Deletable {
                                    delegate.delete()
                                }
                                self.dismiss(animated: true)
                            }
                        }
                    }
                }
            }
        )
        present(controller, animated: true)
    }
    
    // Allows user to share the memory image.
    @objc func shareButtonPressed() {
        var itemsToShare: [Any] = []

        if let image = memoryImage.image {
            itemsToShare.append(image)
        }

        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        
        activityViewController.excludedActivityTypes = [
            .addToReadingList,
            .addToHomeScreen,
            .collaborationCopyLink,
            .collaborationInviteWithLink,
            .openInIBooks,
        ]
        
        present(activityViewController, animated: true, completion: nil)
    }

    // Editing sends the memory details to the editing view controller.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditSegue",
           let nextVC = segue.destination as? MemoryEditViewController {
            nextVC.delegate = self
            self.memory.title = memoryTitle.text!
            self.memory.description = memoryDescription.text!
            nextVC.memory = self.memory
        }
    }

    // When memory is edited, changes the fields to reflect new information.
    func update(newTitle: String, newDescription: String) {
        let delegate = delegate as! Updatable
        memoryTitle.text = newTitle
        memoryDescription.text = newDescription
        delegate.update(newTitle: newTitle, newDescription: newDescription)
    }
    
}
