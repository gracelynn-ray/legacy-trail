import UIKit
import FirebaseAuth
import SDWebImage

// Tab bar controller used to navigate app sections.
class CustomTabBarController: UITabBarController, UITabBarControllerDelegate {
    
    var initialIndex = 1 // Launch app on camera screen.
    var noProfilePicture = true // Display user's profile picture on profile tab.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        
        selectedIndex = initialIndex
        tabBar.backgroundColor = .black // Background color is black on camera screen.
        tabBar.tintColor = .white // White icon on black background color.
        
        setProfilePictureAsTabIcon()
        if noProfilePicture {
            self.viewControllers?.last!.tabBarItem.image = UIImage(systemName: "person.crop.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal) // Default person icon if no profile picture.
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateProfilePictureIcon), name: NSNotification.Name("ProfilePictureUpdated"), object: nil) // Check if profile picture has changed.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let customHeight: CGFloat = 90
        var tabBarFrame = tabBar.frame
        tabBarFrame.size.height = customHeight
        tabBarFrame.origin.y = view.frame.height - customHeight
        tabBar.frame = tabBarFrame
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Update tab bar colors when new tab is selected.
        if selectedIndex == 1 {
            // Camera tab bar color is always black.
            tabBar.backgroundColor = .black
            tabBar.tintColor = .white
        } else {
            // Based off light or dark mode.
            tabBar.backgroundColor = .systemBackground
            tabBar.tintColor = .label
        }
        
        // Change the color to represent selected tab.
        if selectedIndex == 2 && noProfilePicture {
            self.viewControllers?.last!.tabBarItem.image = UIImage(systemName: "person.crop.circle.fill")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        } else if noProfilePicture {
            self.viewControllers?.last!.tabBarItem.image = UIImage(systemName: "person.crop.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        }
    }
    
    // Recieves trigger to update profile picture icon.
    @objc private func updateProfilePictureIcon() {
        setProfilePictureAsTabIcon()
    }
        
    // Remove notification data when the controller is deinitialized.
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ProfilePictureUpdated"), object: nil)
    }
        
    // Grabs current profile picture and adds it to tab bar.
    private func setProfilePictureAsTabIcon() {
        let profileTab = viewControllers?.last
        
        if let user = Auth.auth().currentUser, let profilePictureURL = user.photoURL {
            // Download the user's profile picture.
            SDWebImageManager.shared.loadImage(with: profilePictureURL, options: .highPriority, progress: nil) {
                image, _, _, _, _, _ in if let image = image {
                    let resizedImage = self.resizeImage(image: image, targetSize: CGSize(width: 26, height: 26))
                    let circularImage = self.makeCircularImage(resizedImage, size: CGSize(width: 26, height: 26))
                    profileTab!.tabBarItem.image = circularImage.withRenderingMode(.alwaysOriginal)
                    profileTab!.tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: -5, right: 0)
                    self.noProfilePicture = false
                } else {
                    self.noProfilePicture = true
                }
            }
        } else {
            noProfilePicture = true
        }
        
        // Uses default image if no profile picture.
        if noProfilePicture {
            var tabIcon = UIImage(systemName: "person.crop.circle.fill") ?? UIImage()
            let resizedImage = resizeImage(image: tabIcon, targetSize: CGSize(width: 26, height: 26))
            let circularImage = makeCircularImage(resizedImage, size: CGSize(width: 26, height: 26))
            profileTab!.tabBarItem.image = circularImage.withRenderingMode(.alwaysOriginal)
            profileTab!.tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: -5, right: 0)
        }
        
        // Change the color to represent selected tab.
        if selectedIndex == 2 && noProfilePicture {
            self.viewControllers?.last!.tabBarItem.image = UIImage(systemName: "person.crop.circle.fill")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        } else if noProfilePicture {
            self.viewControllers?.last!.tabBarItem.image = UIImage(systemName: "person.crop.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        }
    }

    // Resize profile picture to fit custom navigation conroller icon.
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledImageSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        UIGraphicsBeginImageContextWithOptions(scaledImageSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage ?? image
    }
        
    // Reformat the image to be circular.
    private func makeCircularImage(_ image: UIImage, size: CGSize) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        UIBezierPath(roundedRect: rect, cornerRadius: size.width / 2).addClip()
        image.draw(in: rect)
        let circularImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return circularImage ?? image
    }
}
