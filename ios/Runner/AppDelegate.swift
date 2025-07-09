import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    //Needed inorder to make audio recordings not soft
      do {
         let session = AVAudioSession.sharedInstance()
         try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
         try session.setActive(true)
      } catch {
         debugPrint("Problem with AVAudioSession")
      }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
