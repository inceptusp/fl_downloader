part of 'fl_downloader_src.dart';

class _WindowsImpl {
  static final forbiddenChars = RegExp("[#%&{}<>*?/\$!'\":@+`|=]");

  static _PreparedDownloadData prepareDownloadData(
    String url, {
    String? fileName,
  }) {
    final uri = Uri.parse(url);
    late final String fileNm;

    if (fileName != null) {
      fileNm = fileName.replaceAll('/', '\\').replaceAll(forbiddenChars, '-');
    } else {
      fileNm = uri.pathSegments.last.replaceAll('\\', '-').replaceAll(
            forbiddenChars,
            '-',
          );
    }

    return _PreparedDownloadData(
      url: url,
      fileName: fileNm,
    );
  }
}

class _PreparedDownloadData {
  final String url;
  final String fileName;

  _PreparedDownloadData({
    required this.url,
    required this.fileName,
  });
}
