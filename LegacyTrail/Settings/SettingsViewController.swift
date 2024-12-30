import UIKit

// View controller that shows settings categories.
class SettingsViewController: UIViewController {

    @IBOutlet weak var lightModeSwitch: UISwitch!
    
    // Changes app to light or dark mode based on switch. Remembers user's decision by saving in user defaults.
    @IBAction func LightModeSwitch(_ sender: UISwitch) {
        if sender.isOn {
            setAppInterfaceStyle(.light)
            UserDefaults.standard.set("light", forKey: "theme")
        } else {
            setAppInterfaceStyle(.dark)
            UserDefaults.standard.set("dark", forKey: "theme")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = UserDefaults.standard.string(forKey: "theme") ?? "light"
        lightModeSwitch.setOn(theme == "light", animated: false)
        setAppInterfaceStyle(theme == "light" ? .light : .dark)
        
        let backButton = UIBarButtonItem()
        backButton.tintColor = .label
        navigationItem.backBarButtonItem = backButton
    }
    
    private func setAppInterfaceStyle(_ style: UIUserInterfaceStyle) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
