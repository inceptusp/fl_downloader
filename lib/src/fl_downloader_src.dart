import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

part 'progress_entity_src.dart';

class FlDownloader {
  static const MethodChannel _channel = MethodChannel(
    'dev.inceptusp.fl_downloader',
  );
  static final StreamController<Progress> _progressStream = StreamController.broadcast();

  static Stream<Progress> get progressStream => _progressStream.stream;

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

  static Future openFile(int downloadId) async {
    return await _channel.invokeMethod('openFile', {
      'downloadId': downloadId,
    });
  }

  static Future<int> cancel(List<int> downloadIds) async {
    final convertedIds = Int64List.fromList(downloadIds);
    return await _channel.invokeMethod('cancel', {
      'downloadIds': convertedIds,
    });
  }
}
