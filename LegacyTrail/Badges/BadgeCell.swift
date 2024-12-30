import UIKit

// Custom cell for badges table.
class BadgeCell: UITableViewCell {
    
    let badgeImage = UIImageView()
    let titleLabel = UILabel()
    let descriptionLabel = UILabel()
    let percentageLabel = UILabel() // Indicates user's percentage progress toward badge.
    let progressLabel = UILabel() // Indicates user's number completed progress toward badge.
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Set up view components programmatically.
        badgeImage.contentMode = .scaleAspectFit
        badgeImage.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeImage)
        
        titleLabel.font = UIFont(name: "Avenir Next Medium", size: 16)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        descriptionLabel.font = UIFont(name: "Avenir Light", size: 12)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        percentageLabel.font = UIFont.systemFont(ofSize: 16)
        percentageLabel.textColor = .label
        percentageLabel.textAlignment = .center
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(percentageLabel)
        
        progressLabel.font = UIFont.systemFont(ofSize: 10)
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressLabel)
        
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.backgroundColor = .systemBackground
        contentView.layer.masksToBounds = false
        
        // Set up view constraints programmatically.
        NSLayoutConstraint.activate([
            badgeImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            badgeImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badgeImage.widthAnchor.constraint(equalToConstant: 50),
            badgeImage.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: badgeImage.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descriptionLabel.leadingAnchor.constraint(equalTo: badgeImage.trailingAnchor, constant: 10),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            percentageLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -5),
            percentageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            percentageLabel.widthAnchor.constraint(equalToConstant: 35),
            
            progressLabel.topAnchor.constraint(equalTo: percentageLabel.bottomAnchor, constant: 2),
            progressLabel.trailingAnchor.constraint(equalTo: percentageLabel.trailingAnchor),
            progressLabel.widthAnchor.constraint(equalTo: percentageLabel.widthAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
