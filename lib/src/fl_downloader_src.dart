import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_permission_status.dart';

part 'progress_entity_src.dart';

class FlDownloader {
  static const MethodChannel _channel = MethodChannel(
    'dev.inceptusp.fl_downloader',
  );

  static StreamController<bool> _permissionStatusStream = StreamController();
  static final StreamController<DownloadProgress> _progressStream =
      StreamController.broadcast();

  static Stream<DownloadProgress> get progressStream => _progressStream.stream;

  /// Initializes the plugin and open the stream to listen to download progress
  static Future initialize() async {
    _channel.setMethodCallHandler((call) {
      if (call.method == 'notifyProgress') {
        final map = call.arguments as Map;
        _progressStream.add(
          DownloadProgress._fromMap(<String, dynamic>{...map}),
        );
      }
      if (call.method == 'onRequestPermissionResult') {
        final result = call.arguments as bool;
        _permissionStatusStream.add(result);
        _permissionStatusStream.close();
        _permissionStatusStream = StreamController();
      }
      return Future.value(null);
    });
  }

  /// Requests storage permission on Android
  ///
  /// If you app supports Android 9 or lower, the call to request storage permission
  /// is mandatory. Aways returns [StoragePermissionStatus.granted] on Android 10 or higher and on iOS.
  static Future<StoragePermissionStatus> requestPermission() async {
    if (Platform.isIOS) return StoragePermissionStatus.granted;
    try {
      final status = await _channel.invokeMethod<bool>(
        'checkStoragePermission',
      );
      if (status == true) return StoragePermissionStatus.granted;
    } catch (e) {
      debugPrint(e.toString());
      return StoragePermissionStatus.unknown;
    }

    try {
      bool? permissionStatus;
      await _channel.invokeMethod<bool>('requestStoragePermission');
      await for (bool event in _permissionStatusStream.stream) {
        permissionStatus = event;
      }
      if (permissionStatus == null) return StoragePermissionStatus.unknown;
      if (permissionStatus) {
        return StoragePermissionStatus.granted;
      } else {
        return StoragePermissionStatus.denied;
      }
    } catch (e) {
      debugPrint(e.toString());
      return StoragePermissionStatus.unknown;
    }
  }

  /// Create and starts a downlaod task on a local URLSession on iOS or
  /// on the system download manager on Android
  ///
  /// Returns the id of the download task
  ///
  /// If a fileName is not provided, the file name will be extracted from the url and
  /// if the name extracted from the url contains forbidden characters, this characters
  /// will be replaced by a dash (-). The list of forbidden characters are:
  /// ```bash
  /// # % & { } \ < > * ? / $ ! ' " : @ + ` | =
  /// ```
  /// (which covers all characters that are not allowed in most file systems)
  static Future<int> download(
    String url, {
    Map<String, String>? headers,
    String? fileName,
  }) async {
    return await _channel.invokeMethod('download', <String, dynamic>{
      'url': url,
      'headers': headers,
      'fileName': fileName,
    });
  }

  /// Open the downlaoded file on the default file loader on each platform
  ///
  /// You can open a downloaded file using the [downloadId] or the [filepath]
  /// on Android. On iOS you can open using only the [filePath]
  static Future openFile({int? downloadId, String? filePath}) async {
    assert(
      (downloadId != null) ^ (filePath != null),
      'You can open a file by downloadId or by filePath, not both',
    );
    assert(
      !Platform.isIOS || (Platform.isIOS && filePath != null),
      'On iOS you can only open a file by filePath',
    );
    return await _channel.invokeMethod('openFile', {
      'downloadId': downloadId,
      'filePath': filePath,
    });
  }

  /// Cancels a list of ongoing downloads and return the number of canceled tasks
  static Future<int> cancel(List<int> downloadIds) async {
    final convertedIds = Int64List.fromList(downloadIds);
    return await _channel.invokeMethod('cancel', {
      'downloadIds': convertedIds,
    });
  }
}
