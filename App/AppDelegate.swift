import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options: UIScene.ConnectionOptions,
	) -> UISceneConfiguration {
		let configuration = UISceneConfiguration(name: "Reproduction", sessionRole: connectingSceneSession.role)
		configuration.delegateClass = SceneDelegate.self
		return configuration
	}
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow? = nil

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
		guard let scene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: scene)
		window.rootViewController = ReproductionViewController()
		window.makeKeyAndVisible()
		self.window = window
	}
}
