import Flutter
import UIKit

@available(iOS 11.0, *)
public class SwiftFlDownloaderPlugin: NSObject, FlutterPlugin, URLSessionDelegate, URLSessionDownloadDelegate {
    public static var channel : FlutterMethodChannel?
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo fileURL: URL) {
        do {
            let documentsURL = try
            FileManager.default.url(for: .downloadsDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
            let savedURL = documentsURL.appendingPathComponent(fileURL.lastPathComponent)
            try FileManager.default.moveItem(at: fileURL, to: savedURL)
            SwiftFlDownloaderPlugin.channel?.invokeMethod("notifyProgress", arguments:[
                "downloadId": downloadTask.taskIdentifier,
                "progress": 100,
                "status": 0,
                "filePath": savedURL
            ])
        } catch {
            print ("file error: \(error)")
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
        let percentage = (Float.init(current)/Float.init(total))*100.0
        SwiftFlDownloaderPlugin.channel?.invokeMethod("notifyProgress", arguments:[
            "downloadId": downloadTask.taskIdentifier,
            "progress": Int.init(percentage),
            "status": Int.init(stateMapper[downloadTask.state]!),
        ])
    }
    
    private lazy var urlSession = URLSession(configuration: .default,
                                               delegate: self,
                                               delegateQueue: nil)

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
            openFile(path: arguments["fileName"] as! String)
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
        return downloadTask.taskIdentifier
    }

    public func openFile(path: String) {
        let docController = UIDocumentInteractionController.init(url: URL(string: path)!)
        docController.presentPreview(animated: true)
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
