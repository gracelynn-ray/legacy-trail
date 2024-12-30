import UIKit

// Custom collection view cell for memories.
class MemoriesCollectionViewCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    let title = UILabel()
    let memoryDescription = UILabel()
    let memoryDate = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let theme = UserDefaults.standard.string(forKey: "theme") ?? "light"
        
        // Creates custom collection view cell programmatically. Displays memory details.
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 15
        imageView.clipsToBounds = true
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
        imageView.layer.shadowOpacity = 0.3
        imageView.layer.shadowRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        title.font = UIFont(name: "PlayfairDisplay-Regular", size: 20)
        title.textColor = .label
        title.numberOfLines = 1
        title.translatesAutoresizingMaskIntoConstraints = false
        
        memoryDate.font = UIFont(name: "Avenir Medium", size: 14)
        memoryDate.textColor = .secondaryLabel
        memoryDate.translatesAutoresizingMaskIntoConstraints = false
    
        contentView.addSubview(imageView)
        contentView.addSubview(title)
        contentView.addSubview(memoryDate)
        
        // Sets up constraints programmatically.
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            imageView.heightAnchor.constraint(equalToConstant: 200),
            
            title.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            memoryDate.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            memoryDate.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
        ])
        
        contentView.layer.cornerRadius = 15
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
        contentView.layer.shadowRadius = 4
        contentView.backgroundColor = theme == "light" ? .systemBackground : .secondarySystemBackground
        contentView.layer.masksToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
