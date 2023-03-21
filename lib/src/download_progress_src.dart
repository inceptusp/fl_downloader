part of 'fl_downloader_src.dart';

/// Possible status for download tasks
enum DownloadStatus {
  /// The download has concluded successfully. (considered as finished)
  successful,

  /// The task is running.
  running,

  /// The task has not started yet.
  pending,

  /// The download is paused. (considered as finished)
  paused,

  /// The download has failed. (considered as finished)
  failed,

  /// The download is being canceled.
  ///
  /// This status is only used on iOS.
  canceling,
}

class DownloadProgress {
  /// Download task identifier.
  ///
  /// interger on Android and iOS, string on Windows
  final dynamic downloadId;

  /// File download progress in percentage from 0 to 100
  final int progress;

  /// Download task status as a [DownloadStatus]
  final DownloadStatus status;

  /// Downloaded file path
  late final String? filePath;

  /// Download status reason. This is only available when the download status is failed or paused.
  late final StatusReason? statusReason;

  /// A class that represents the download progress and status
  DownloadProgress({
    required this.downloadId,
    required this.progress,
    required this.status,
    this.filePath,
    this.statusReason,
  });

  factory DownloadProgress._fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      downloadId: map['downloadId'],
      progress: map['progress'],
      status: DownloadStatus.values[map['status']],
      filePath: map.containsKey('filePath') ? map['filePath'] : null,
      statusReason: map.containsKey('reason')
          ? StatusReason._fromMap({
              'code': map['reason'] != null
                  ? map['reason'].toString().split(RegExp(r'\(|\)'))[1]
                  : -1,
              'type': map['reason'] != null
                  ? map['reason'].toString().split('(')[0]
                  : null,
              'message': map['reason'],
            })
          : null,
    );
  }

  @override
  String toString() {
    return 'Progress{downloadId: $downloadId, progress: $progress, status: $status, filePath: $filePath, statusReason: $statusReason}';
  }
}

class StatusReason {
  /// Status reason code
  final int code;

  /// Reason type
  ///
  /// Can be one of the following: <br> <br>
  /// * `ANDROID_ERROR` (in case of an error on Android) <br>
  /// * `IOS_ERROR` (in case of an error on iOS) <br>
  /// * `HTTP_ERROR` (in case of an HTTP error) <br>
  /// * `ANDROID` (in case of a pause reason on Android)
  final String? type;

  /// Status reason message
  final String? message;

  /// A class that carries extra messages for download status when it is failed or paused
  StatusReason({
    required this.code,
    this.type,
    this.message,
  });

  factory StatusReason._fromMap(Map<String, dynamic> map) {
    final statusCode = map['code'].toString();
    return StatusReason(
      code: int.parse(
        statusCode.isEmpty ? '-1' : statusCode,
      ),
      message: map['message'],
    );
  }

  @override
  String toString() {
    return 'StatusReason{code: $code, message: $message}';
  }
}
