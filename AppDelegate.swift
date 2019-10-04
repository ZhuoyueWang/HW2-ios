import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // When the app is under background, state need to change
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save data when in background
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Transition state to active from background to foreground
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart inavtive tasks
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // To terminate
    }


}

