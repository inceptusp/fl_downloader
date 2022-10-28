import Flutter
import os
import UIKit

public class SwiftFlDownloaderPlugin: NSObject, FlutterPlugin {
    private static let kFlutterChannelName: String = "dev.inceptusp.fl_downloader"
    private static let kDownloadMethodName: String = "download"
    private static let kOpenFileMethodName: String = "openFile"
    private static let kCancelMethodName: String = "cancel"
    private static let kNotifyProgressMethodName: String = "notifyProgress"
    private static let kDownloadNamesUD: String = "downloadNames"
    
    private lazy var fpController = UIDocumentInteractionController()
    private lazy var urlSession = URLSession(configuration: .default,
                                               delegate: self,
                                               delegateQueue: nil)
    
    public static var channel : FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: kFlutterChannelName, binaryMessenger: registrar.messenger())
        let instance = SwiftFlDownloaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel!)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments: Dictionary<String, Any> = call.arguments as! Dictionary<String, Any>
        if call.method == SwiftFlDownloaderPlugin.kDownloadMethodName {
            let taskId = download(url: arguments["url"] as! String,
                  headers: arguments["headers"] as? [String: String],
                  fileName: arguments["fileName"] as? String)
            result(taskId)
        } else if call.method == SwiftFlDownloaderPlugin.kOpenFileMethodName {
            openFile(path: arguments["filePath"] as! String)
        } else if call.method == SwiftFlDownloaderPlugin.kCancelMethodName {
            result(cancel(taskIds: arguments["downloadIds"] as! [Int]))
        } else {
            result(FlutterMethodNotImplemented)
        }
      }

    private func download(url: String, headers: [String: String]?, fileName: String?) -> Int {
        let request: URLRequest = {
            var request = URLRequest(url: URL(string: url)!)
            for (key, value) in headers ?? [:] {
                request.addValue(value, forHTTPHeaderField: key)
            }
            return request
        }()

        let downloadTask = urlSession.downloadTask(with: request)
        downloadTask.resume()
        
        let prefs = UserDefaults.standard;
        if prefs.object(forKey: SwiftFlDownloaderPlugin.kDownloadNamesUD) != nil {
            var downloadNames = prefs.array(forKey: SwiftFlDownloaderPlugin.kDownloadNamesUD)
            let dict = ["url": downloadTask.originalRequest?.url?.absoluteString ?? "",
                        "fileName": fileName ?? ""] as [String : Any]
            downloadNames?.append(dict)
            prefs.set(downloadNames, forKey: SwiftFlDownloaderPlugin.kDownloadNamesUD)
        } else {
            let dict = ["url": downloadTask.originalRequest?.url?.absoluteString ?? "",
                        "fileName": fileName ?? ""] as [String : Any]
            let list: Array = [dict]
            prefs.set(list, forKey: SwiftFlDownloaderPlugin.kDownloadNamesUD)
        }
        
        return downloadTask.taskIdentifier
    }

    private func openFile(path: String) {
        fpController.url = URL(string: path)!
        fpController.delegate = self
        fpController.presentPreview(animated: true)
    }

    private func cancel(taskIds: [Int]) -> Int{
        var count = 0
        urlSession.getTasksWithCompletionHandler
        {
            (dataTasks, uploadTasks, downloadTasks) -> Void in
            downloadTasks.forEach { task in
                if (taskIds.contains(task.taskIdentifier)) {
                    task.cancel()
                    count += 1
                }
            }
        }
        return count
    }
}

extension SwiftFlDownloaderPlugin: URLSessionDelegate, URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo fileURL: URL) {
        var downloadNames = UserDefaults.standard.array(forKey: SwiftFlDownloaderPlugin.kDownloadNamesUD)
        var fileName: String?
        
        do {
            let httpResponse = downloadTask.response as! HTTPURLResponse;
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            if let dict = downloadNames?.first(where: {
                ($0 as! Dictionary<String, Any>)["url"] as! String == downloadTask.originalRequest?.url?.absoluteString ?? ""
            }) {
                fileName = (dict as! Dictionary<String, Any>)["fileName"] as? String
                downloadNames?.removeAll(where: {
                    ($0 as! Dictionary<String, Any>)["url"] as! String == (dict as! Dictionary<String, Any>)["url"] as! String
                })
                UserDefaults.standard.set(downloadNames, forKey: SwiftFlDownloaderPlugin.kDownloadNamesUD)
            }
            
            let documentsURL = try
            FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
                let filename = fileName!.isEmpty ? downloadTask.currentRequest?.url?.lastPathComponent.removingRegexMatches(pattern: "[#%&{}\\\\<>*?/$!'\":@+`|=]", replaceWith: "-") ?? "unknown" : fileName!
            let savedURL = documentsURL.appendingPathComponent(filename)
            do {
                try FileManager.default.removeItem(at: savedURL)
            } catch {}
                try FileManager.default.moveItem(at: fileURL, to: savedURL)
                SwiftFlDownloaderPlugin.channel?.invokeMethod(SwiftFlDownloaderPlugin.kNotifyProgressMethodName, arguments:[
                "downloadId": downloadTask.taskIdentifier,
                "progress": 100,
                "status": 0,
                "filePath": savedURL.absoluteString
            ])
            } else {
                if #available(iOS 14.0, *) {
                    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "fl_downloader")
                    logger.info("Download failed. HTTP Status \(httpResponse.statusCode)")
                } else {
                    NSLog("Download failed. HTTP Status %d", httpResponse.statusCode)
                }
                SwiftFlDownloaderPlugin.channel?.invokeMethod(SwiftFlDownloaderPlugin.kNotifyProgressMethodName, arguments:[
                    "downloadId": downloadTask.taskIdentifier,
                    "progress": 0,
                    "status": 4,
                ])
            }
        } catch {
            if #available(iOS 14.0, *) {
                let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "fl_downloader")
                logger.error("Error saving downloaded file: \(error as NSError)")
            } else {
                NSLog("Error saving downloaded file: %@", error as NSError)
            }
        }
    }
    
    public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten current: Int64, totalBytesExpectedToWrite total: Int64) {
        let stateMapper =
        [
            URLSessionTask.State.completed: 0,
            URLSessionTask.State.running: 1,
            URLSessionTask.State.suspended: 3,
            URLSessionTask.State.canceling: 5
        ]
        let percentage = (Float.init(current) / Float.init(total)) * 100.0
        SwiftFlDownloaderPlugin.channel?.invokeMethod(SwiftFlDownloaderPlugin.kNotifyProgressMethodName, arguments:[
            "downloadId": downloadTask.taskIdentifier,
            "progress": Int.init(percentage),
            "status": Int.init(stateMapper[downloadTask.state]!),
        ])
    }
}

extension SwiftFlDownloaderPlugin: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window!.rootViewController!
        } else {
            let app = UIApplication.shared
            return app.windows.first!.rootViewController!;
        }
    }
}

extension String {
    func removingRegexMatches(pattern: String, replaceWith: String = "") -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch { return nil }
    }
}
