import Flutter
import UIKit

public class SwiftFlDownloaderPlugin: NSObject, FlutterPlugin {
    public static var channel : FlutterMethodChannel?
    
    private lazy var urlSession = URLSession(configuration: .default,
                                               delegate: self,
                                               delegateQueue: nil)
    
    private lazy var fpController = UIDocumentInteractionController()

    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "dev.inceptusp.fl_downloader", binaryMessenger: registrar.messenger())
        let instance = SwiftFlDownloaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel!)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments: Dictionary<String, Any> = call.arguments as! Dictionary<String, Any>
        if call.method == "download" {
            let taskId = download(url: arguments["url"] as! String,
                  headers: arguments["headers"] as? [String: String],
                  fileName: arguments["fileName"] as? String)
            result(taskId)
        } else if call.method == "openFile" {
            openFile(path: arguments["filePath"] as! String)
        } else if call.method == "cancel" {
            result(cancel(taskIds: arguments["downloadIds"] as! [Int]))
        } else {
            result(FlutterMethodNotImplemented)
        }
      }

    public func download(url: String, headers: [String: String]?, fileName: String?) -> Int {
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
        if prefs.object(forKey: "downloadNames") != nil {
            var downloadNames = prefs.array(forKey: "downloadNames")
            let dict = ["url": downloadTask.originalRequest?.url?.absoluteString ?? "",
                        "fileName": fileName ?? ""] as [String : Any]
            downloadNames?.append(dict)
        } else {
            let dict = ["url": downloadTask.originalRequest?.url?.absoluteString ?? "",
                        "fileName": fileName ?? ""] as [String : Any]
            let list: Array = [dict]
            prefs.set(list, forKey: "downloadNames")
        }
        
        return downloadTask.taskIdentifier
    }

    public func openFile(path: String) {
        fpController.url = URL(string: path)!
        fpController.delegate = self
        fpController.presentPreview(animated: true)
    }

    public func cancel(taskIds: [Int]) -> Int{
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
        var downloadNames = UserDefaults.standard.array(forKey: "downloadNames")
        var fileName: String?
        do {
            if let dict = downloadNames?.first(where: { ($0 as! Dictionary<String, Any>)["url"] as! String == downloadTask.originalRequest?.url?.absoluteString ?? ""}) {
                fileName = (dict as! Dictionary<String, Any>)["fileName"] as? String
                downloadNames?.removeAll(where: { ($0 as! Dictionary<String, Any>)["url"] as! String == (dict as! Dictionary<String, Any>)["url"] as! String })
            }
            
            let documentsURL = try
            FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
            let filename = fileName ?? downloadTask.currentRequest?.url?.lastPathComponent ?? ""
            let savedURL = documentsURL.appendingPathComponent(filename)
            do {
                try FileManager.default.removeItem(at: savedURL)
            } catch {}
                try FileManager.default.moveItem(at: fileURL, to: savedURL)
            SwiftFlDownloaderPlugin.channel?.invokeMethod("notifyProgress", arguments:[
                "downloadId": downloadTask.taskIdentifier,
                "progress": 100,
                "status": 0,
                "filePath": savedURL.absoluteString
            ])
        } catch {
            print ("Error saving downloaded file: \(error)")
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
        SwiftFlDownloaderPlugin.channel?.invokeMethod("notifyProgress", arguments:[
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
