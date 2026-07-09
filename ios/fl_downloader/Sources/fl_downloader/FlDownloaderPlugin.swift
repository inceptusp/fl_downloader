import Flutter
import os
import UIKit

public class FlDownloaderPlugin: NSObject, FlutterPlugin {
    private static let kFlutterChannelName: String = "dev.inceptusp.fl_downloader"
    private static let kDownloadMethodName: String = "download"
    private static let kOpenFileMethodName: String = "openFile"
    private static let kCancelMethodName: String = "cancel"
    private static let kNotifyProgressMethodName: String = "notifyProgress"
    private static let kDownloadNamesUD: String = "downloadNames"
    
    private lazy var fpController = UIDocumentInteractionController()
    private lazy var urlSession = URLSession(configuration: .default,
                                             delegate: self,
                                             delegateQueue: OperationQueue.main)
    
    public static var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: kFlutterChannelName, binaryMessenger: registrar.messenger())
        let instance = FlDownloaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel!)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterMethodNotImplemented)
            return
        }
        
        if call.method == FlDownloaderPlugin.kDownloadMethodName {
            guard let url = arguments["url"] as? String else {
                result(FlutterError(code: "INVALID_URL", message: "URL is required", details: nil))
                return
            }
            
            let taskId = download(url: url,
                                  headers: arguments["headers"] as? [String: String],
                                  fileName: arguments["fileName"] as? String)
            result(taskId)
        } else if call.method == FlDownloaderPlugin.kOpenFileMethodName {
            if let filePath = arguments["filePath"] as? String {
                openFile(path: filePath)
            }
            result(nil)
        } else if call.method == FlDownloaderPlugin.kCancelMethodName {
            let downloadIds = arguments["downloadIds"] as? [Int] ?? []
            cancel(taskIds: downloadIds, result: result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func download(url: String, headers: [String: String]?, fileName: String?) -> Int {
        guard let encodedUrl = URL(string: url) else { return -1 }
        var request = URLRequest(url: encodedUrl)
        
        for (key, value) in headers ?? [:] {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let downloadTask = urlSession.downloadTask(with: request)
        downloadTask.resume()
        
        let prefs = UserDefaults.standard
        var downloadNames = prefs.array(forKey: FlDownloaderPlugin.kDownloadNamesUD) as? [[String: Any]] ?? []
        
        let dict: [String: Any] = [
            "url": downloadTask.originalRequest?.url?.absoluteString ?? "",
            "fileName": fileName ?? ""
        ]
        downloadNames.append(dict)
        prefs.set(downloadNames, forKey: FlDownloaderPlugin.kDownloadNamesUD)
        
        return downloadTask.taskIdentifier
    }

    private func openFile(path: String) {
        if let actualURL = URL(string: path) {
            fpController.url = actualURL
            fpController.delegate = self
            fpController.presentPreview(animated: true)
        }
    }

    private func cancel(taskIds: [Int], result: @escaping FlutterResult) {
        urlSession.getTasksWithCompletionHandler { (_, _, downloadTasks) in
            var count = 0
            downloadTasks.forEach { task in
                if taskIds.contains(task.taskIdentifier) {
                    task.cancel()
                    count += 1
                }
            }
            DispatchQueue.main.async {
                result(count)
            }
        }
    }
}

extension FlDownloaderPlugin: URLSessionDelegate, URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo fileURL: URL) {
        let prefs = UserDefaults.standard
        var downloadNames = prefs.array(forKey: FlDownloaderPlugin.kDownloadNamesUD) as? [[String: Any]] ?? []
        var fileName: String?
        let originalUrlStr = downloadTask.originalRequest?.url?.absoluteString ?? ""
        
        if let index = downloadNames.firstIndex(where: { ($0["url"] as? String) == originalUrlStr }) {
            fileName = downloadNames[index]["fileName"] as? String
            downloadNames.remove(at: index)
            prefs.set(downloadNames, forKey: FlDownloaderPlugin.kDownloadNamesUD)
        }
        
        guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
            sendError(task: downloadTask, reason: "INVALID_RESPONSE", message: "Response was not an HTTP response.")
            return
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            logMessage("Download failed. HTTP Status \(httpResponse.statusCode)", isError: true)
            FlDownloaderPlugin.channel?.invokeMethod(FlDownloaderPlugin.kNotifyProgressMethodName, arguments: [
                "downloadId": downloadTask.taskIdentifier,
                "progress": 0,
                "status": 4,
                "reason": "HTTP_ERROR(\(httpResponse.statusCode))",
                "downloadUrl": originalUrlStr
            ])
            return
        }
        
        do {
            let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            
            let fallbackName = downloadTask.currentRequest?.url?.lastPathComponent ?? "unknown"
            var finalFileName = (fileName == nil || fileName!.isEmpty) ? fallbackName : fileName!
            
            let forbiddenChars = CharacterSet(charactersIn: #"#%&{}\<>*?$!'":@+`|="#)
            finalFileName = finalFileName.replacingCharacters(in: forbiddenChars, with: "-")
            
            let savedURL = documentsURL.appendingPathComponent(finalFileName)
            
            try? FileManager.default.removeItem(at: savedURL)
            try FileManager.default.createDirectory(at: savedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: fileURL, to: savedURL)
            
            FlDownloaderPlugin.channel?.invokeMethod(FlDownloaderPlugin.kNotifyProgressMethodName, arguments: [
                "downloadId": downloadTask.taskIdentifier,
                "progress": 100,
                "status": 0,
                "filePath": savedURL.absoluteString,
                "downloadUrl": originalUrlStr
            ])
        } catch {
            logMessage("Error saving downloaded file: \(error)", isError: true)
            sendError(task: downloadTask, reason: "IOS_ERROR(\((error as NSError).code))", message: error.localizedDescription)
        }
    }
    
    public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten current: Int64, totalBytesExpectedToWrite total: Int64) {
        let stateMapper: [URLSessionTask.State: Int] = [.completed: 0, .running: 1, .suspended: 3, .canceling: 5]
        
        let percentage = total > 0 ? (Float(current) / Float(total)) * 100.0 : -1.0

        guard downloadTask.state != .completed else {
            return
        }

        FlDownloaderPlugin.channel?.invokeMethod(FlDownloaderPlugin.kNotifyProgressMethodName, arguments: [
            "downloadId": downloadTask.taskIdentifier,
            "progress": Int(percentage),
            "status": stateMapper[downloadTask.state] ?? 1,
            "downloadUrl": downloadTask.originalRequest?.url?.absoluteString ?? ""
        ])
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let prefs = UserDefaults.standard
        var downloadNames = prefs.array(forKey: FlDownloaderPlugin.kDownloadNamesUD) as? [[String: Any]] ?? []
        let originalUrlStr = task.originalRequest?.url?.absoluteString ?? ""
        
        if let index = downloadNames.firstIndex(where: { ($0["url"] as? String) == originalUrlStr }) {
            downloadNames.remove(at: index)
            prefs.set(downloadNames, forKey: FlDownloaderPlugin.kDownloadNamesUD)
        }

        if let nsError = error as? NSError {
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                FlDownloaderPlugin.channel?.invokeMethod(FlDownloaderPlugin.kNotifyProgressMethodName, arguments: [
                    "downloadId": task.taskIdentifier,
                    "progress": 0,
                    "status": 5,
                    "downloadUrl": task.originalRequest?.url?.absoluteString ?? ""
                ])
                return
            }
            sendError(task: task, reason: "IOS_ERROR(\(nsError.code))", message: nsError.localizedDescription)
        }
    }
    
    private func sendError(task: URLSessionTask, reason: String, message: String) {
        FlDownloaderPlugin.channel?.invokeMethod(FlDownloaderPlugin.kNotifyProgressMethodName, arguments: [
            "downloadId": task.taskIdentifier,
            "progress": 0,
            "status": 4,
            "reason": "\(reason): \(message)",
            "downloadUrl": task.originalRequest?.url?.absoluteString ?? ""
        ])
    }
    
    private func logMessage(_ message: String, isError: Bool) {
        if #available(iOS 14.0, *) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "fl_downloader", category: "fl_downloader")
            isError ? logger.error("\(message)") : logger.info("\(message)")
        } else {
            NSLog(message)
        }
    }
}

extension FlDownloaderPlugin: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if #available(iOS 13.0, *) {
            let activeScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            let rootVC = activeScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            return rootVC ?? UIViewController()
        } else {
            return UIApplication.shared.keyWindow?.rootViewController ?? UIViewController()
        }
    }
}

extension String {
    func replacingCharacters(in characterSet: CharacterSet, with replacement: String) -> String {
        return self.components(separatedBy: characterSet).joined(separator: replacement)
    }
}
