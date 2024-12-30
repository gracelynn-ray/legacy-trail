import UIKit
import FirebaseCore

// Custom table view cell for notifications.
class NotificationTableViewCell: UITableViewCell {
    
    let titleLabel = UILabel()
    let descriptionLabel = UILabel()
    let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Configure title label
        titleLabel.font = UIFont(name: "Avenir Next Demi Bold", size: 16)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        contentView.addSubview(titleLabel)
        
        // Configure description label
        descriptionLabel.font = UIFont(name: "Avenir-Medium", size: 14)
        descriptionLabel.textColor = .gray
        descriptionLabel.numberOfLines = 2
        contentView.addSubview(descriptionLabel)
        
        // Configure date label
        dateLabel.font = UIFont(name: "Avenir-Medium", size: 12)
        dateLabel.textColor = .lightGray
        dateLabel.textAlignment = .right
        contentView.addSubview(dateLabel)
    }
    
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.widthAnchor.constraint(equalToConstant: 300),
            
            // Date label constraints
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 2),
            
            // Description label constraints
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    // Populates view cell with notification information.
    func configure(with notification: Notification) {
        titleLabel.text = notification.title
        descriptionLabel.text = notification.description
        dateLabel.text = formatDate(notification.timestamp)
        if !notification.read {
            contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        } else {
            contentView.backgroundColor = .systemBackground
        }
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        let date = timestamp.dateValue()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        
        return formatter.string(from: date)
    }
}
