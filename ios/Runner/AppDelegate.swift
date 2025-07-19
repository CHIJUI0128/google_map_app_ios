import UIKit
import Flutter
import GoogleMaps  // ✅ 加這行

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ 加入 Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyB2smAfFBVXxy-dP3RxaHRPlfgzDTu-2N8")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}