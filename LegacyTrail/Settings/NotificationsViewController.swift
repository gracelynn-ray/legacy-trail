import UIKit
import FirebaseAuth
import FirebaseFirestore

// View controller that allows user to change notifications preferences.
class NotificationsViewController: UIViewController {
    
    @IBOutlet weak var allNotificationsOff: UISwitch!
    @IBOutlet weak var received: UISwitch!
    @IBOutlet weak var ready: UISwitch!
    @IBOutlet weak var onThisDay: UISwitch!
    
    var userPreferences: [String: Bool] = ["ready": true, "received": true, "day": true]

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
    }
    
    private func loadPreferences() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let db = Firestore.firestore()
        
        // Fetch user's preferences.
        db.collection("preferences").document(userId).getDocument { snapshot, error in
            if error != nil { return }

            // Use fetched preferences or default values.
            if let data = snapshot?.data() {
                self.userPreferences = [
                    "ready": data["ready"] as? Bool ?? true,
                    "received": data["received"] as? Bool ?? true,
                    "day": data["day"] as? Bool ?? true
                ]
            }
            
            DispatchQueue.main.async {
                self.updateSwitches()
            }
        }
    }
    
    // Makes user interface switches match the preferences saved in database.
    private func updateSwitches() {
        ready.isOn = userPreferences["ready"] ?? true
        received.isOn = userPreferences["received"] ?? true
        onThisDay.isOn = userPreferences["day"] ?? true
        
        allNotificationsOff.isOn = !ready.isOn && !received.isOn && !onThisDay.isOn
    }
    
    @IBAction func allNotificationsOffChanged(_ sender: UISwitch) {
        let isOn = !sender.isOn
        
        // Update all switches when "allNotificationsOff" is toggled.
        if !isOn {
            ready.setOn(isOn, animated: true)
            received.setOn(isOn, animated: true)
            onThisDay.setOn(isOn, animated: true)
        }
    }
    
    @IBAction func individualSwitchChanged(_ sender: UISwitch) {
        let isOn = !ready.isOn && !received.isOn && !onThisDay.isOn
        allNotificationsOff.setOn(isOn, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePreferences()
    }
    
    private func savePreferences() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let db = Firestore.firestore()
        
        userPreferences = [
            "ready": ready.isOn,
            "received": received.isOn,
            "day": onThisDay.isOn
        ]

        db.collection("preferences").document(userId).setData(userPreferences) { error in
            if let error = error {
                print("Error saving preferences: \(error.localizedDescription)")
            }
        }
    }
}
