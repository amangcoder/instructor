import Flutter
import UIKit

/// SceneDelegate handles scene lifecycle events for the Instructor app.
///
/// ## Universal Links — Plan Sharing
/// When the app receives a Universal Link with path prefix `/s/`,
/// `SceneDelegate` extracts the share token and navigates the Flutter
/// router to `/shared/:token` so [SharedPlanPreviewScreen] is shown.
///
/// Example URL: `https://instructor-app.io/s/abc123`
/// Extracted token: `abc123`
/// Flutter deep link: `/shared/abc123`
class SceneDelegate: FlutterSceneDelegate {

    // MARK: - Universal Link / Continued Activity

    override func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        // Forward to Flutter first so the framework can handle it.
        super.scene(scene, continue: userActivity)

        guard
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
        else { return }

        handleUniversalLink(incomingURL)
    }

    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        super.scene(scene, openURLContexts: URLContexts)

        guard let url = URLContexts.first?.url else { return }
        handleUniversalLink(url)
    }

    // MARK: - Deep Link Routing

    /// Parses an incoming URL. If it matches the `/s/:token` share pattern,
    /// navigates the Flutter engine to `/shared/:token`.
    private func handleUniversalLink(_ url: URL) {
        guard let token = extractShareToken(from: url), !token.isEmpty else {
            return
        }

        let flutterDeepLink = "/shared/\(token)"
        navigateToFlutterRoute(flutterDeepLink)
    }

    /// Returns the share token from a URL whose path starts with `/s/`.
    ///
    /// - Parameter url: The Universal Link URL.
    /// - Returns: The token string, or `nil` if the URL does not match.
    private func extractShareToken(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let path = components?.path ?? url.path

        // Match /s/<token> — must have exactly the prefix "/s/" and a
        // non-empty token segment.
        let prefix = "/s/"
        guard path.hasPrefix(prefix) else { return nil }

        let token = String(path.dropFirst(prefix.count))
        // Reject empty tokens or tokens that look like sub-paths.
        let cleanToken = token.components(separatedBy: "/").first ?? ""
        return cleanToken.isEmpty ? nil : cleanToken
    }

    /// Sends a navigation event to the Flutter engine by calling GoRouter
    /// via the `flutter/navigation` channel.
    private func navigateToFlutterRoute(_ route: String) {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0 is UIWindowScene }) as? UIWindowScene,
            let rootViewController = windowScene.windows
                .first(where: { $0.isKeyWindow })?.rootViewController
                as? FlutterViewController
        else { return }

        let channel = FlutterMethodChannel(
            name: "instructor/deep_link",
            binaryMessenger: rootViewController.binaryMessenger
        )
        channel.invokeMethod("navigate", arguments: route)
    }
}
