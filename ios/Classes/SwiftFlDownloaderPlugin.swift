import Flutter
import UIKit

public class SwiftFlDownloaderPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dev.inceptusp.fl_downloader", binaryMessenger: registrar.messenger())
    let instance = SwiftFlDownloaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "download" {
      result("iOS " + UIDevice.current.systemVersion)
    } else if call.method == "openFile" {
      openFile()
      result(nil)      
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  public func openFile() {}
}
