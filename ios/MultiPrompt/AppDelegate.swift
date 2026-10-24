import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: ViewController())
        window.makeKeyAndVisible()
        self.window = window

        if #available(iOS 13.0, *) {
            window.overrideUserInterfaceStyle = .dark
        }
        UIApplication.shared.statusBarStyle = .lightContent
        return true
    }
}
