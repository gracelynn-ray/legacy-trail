import UIKit

// Custom table view cells for scheduled time capsules.
class ScheduledTimeCapsuleTableViewCell: UITableViewCell {
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    @IBAction func pressedEditButton(_ sender: Any) {
    }
    
    @IBAction func pressedDeleteButton(_ sender: Any) {
    }
}
