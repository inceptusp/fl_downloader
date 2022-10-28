part of 'fl_downloader_src.dart';

/// Possible status for download tasks
enum DownloadStatus {
  /// The download has concluded successfully.
  successful,

  /// The task is running.
  running,

  /// The task has not started yet.
  pending,

  /// The download is paused.
  paused,

  /// The download has failed.
  failed,

  /// The download is being canceled.
  ///
  /// This status is only used on iOS.
  canceling,
}

class DownloadProgress {
  /// Download task identifier
  final int downloadId;

  /// File download progress in percentage from 0 to 100
  final int progress;

  /// Download task status as a [DownloadStatus]
  final DownloadStatus status;

  /// Downloaded file path
  late final String? filePath;

  /// A class that represents the download progress and status
  DownloadProgress({
    required this.downloadId,
    required this.progress,
    required this.status,
    this.filePath,
  });

  factory DownloadProgress._fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      downloadId: map['downloadId'],
      progress: map['progress'],
      status: DownloadStatus.values[map['status']],
      filePath: map.containsKey('filePath') ? map['filePath'] : null,
    );
  }

  @override
  String toString() {
    return 'Progress{downloadId: $downloadId, progress: $progress, status: $status, filePath: $filePath}';
  }
}
