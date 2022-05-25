part of 'fl_downloader_src.dart';

enum DownloadStatus {
  successful,
  running,
  pending,
  paused,
  failed,
  canceling,
}

class Progress {
  int downloadId;
  int progress;
  DownloadStatus status;

  Progress({
    required this.downloadId,
    required this.progress,
    required this.status,
  });

  factory Progress._fromMap(Map<String, dynamic> map) {
    return Progress(
      downloadId: map['downloadId'],
      progress: map['progress'],
      status: DownloadStatus.values[map['status']],
    );
  }

  @override
  String toString() {
    return 'Progress{downloadId: $downloadId, progress: $progress, status: $status}';
  }
}
