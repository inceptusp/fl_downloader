import Flutter
import UIKit

public class SwiftFlDownloaderPlugin: NSObject, FlutterPlugin {
  private lazy var urlSession = URLSession(configuration: .default,
                                           delegate: self,
                                           delegateQueue: nil)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dev.inceptusp.fl_downloader", binaryMessenger: registrar.messenger())
    let instance = SwiftFlDownloaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "download" {
      download(call.arguments["url"] as! String,
               call.arguments["headers"] as? [String: String],
               call.arguments["fileName"] as? String)
      result(nil)
    } else if call.method == "openFile" {
      openFile()
      result(nil)
    } else if call.method == "cancel" {
      cancel()
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  public func download(url: String, headers: [String: String]?, fileName: String?) {
    let request: URLRequest = {
      var request = URLRequest(url: URL(string: url)!)
      for (key, value) in headers ?? [:] {
        request.addValue(value, forHTTPHeaderField: key)
      }
      return request
    }()

    let downloadTask = urlSession.downloadTask(with: request) {
      urlOrNil, responseOrNil, errorOrNil in
      // check for and handle errors:
      // * errorOrNil should be nil
      // * responseOrNil should be an HTTPURLResponse with statusCode in 200..<299
      
      guard let fileURL = urlOrNil else { return }
      do {
          let documentsURL = try
              FileManager.default.url(for: .documentDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: nil,
                                      create: true)
          let savedURL = documentsURL.appendingPathComponent(fileName ?? fileURL.lastPathComponent)
          try FileManager.default.moveItem(at: fileURL, to: savedURL)
      } catch {
          print ("file error: \(error)")
      }
    }
    downloadTask.resume()
  }

  public func openFile() {}

  public func cancel() {}

  private func trackProgress() {}
}
