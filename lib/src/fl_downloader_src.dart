import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

part 'progress_entity_src.dart';

class FlDownloader {
  static const MethodChannel _channel = MethodChannel(
    'dev.inceptusp.fl_downloader',
  );
  static final StreamController<Progress> _progressStream =
      StreamController.broadcast();

  static Stream<Progress> get progressStream => _progressStream.stream;

  /// Initializes the plugin and open the stream to listen to download progress
  static Future initialize() async {
    _channel.setMethodCallHandler((call) {
      if (call.method == 'notifyProgress') {
        final map = call.arguments as Map;
        _progressStream.add(
          Progress._fromMap(<String, dynamic>{...map}),
        );
      }
      return Future.value(null);
    });
  }

  /// Create and starts a downlaod task on a local URLSession on iOS or
  /// on the system download manager on Android
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
