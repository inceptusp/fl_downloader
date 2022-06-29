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
  final int downloadId;
  final int progress;
  final DownloadStatus status;
  late final String? filePath;

  Progress({
    required this.downloadId,
    required this.progress,
    required this.status,
    this.filePath,
  });

  factory Progress._fromMap(Map<String, dynamic> map) {
    return Progress(
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
