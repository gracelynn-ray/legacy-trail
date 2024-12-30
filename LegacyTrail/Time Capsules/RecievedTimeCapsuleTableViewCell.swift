import UIKit

// Custom table view cell for received time capsules.
class RecievedTimeCapsuleTableViewCell: UITableViewCell {
    
    @IBOutlet weak var senderLabel: UILabel!
    @IBOutlet weak var viewButton: UIButton!
    @IBOutlet weak var mapButton: UIButton!
    @IBOutlet weak var availableLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction func pressedViewButton(_ sender: Any) {
    }
}
