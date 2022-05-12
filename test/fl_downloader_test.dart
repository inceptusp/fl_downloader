import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_downloader/fl_downloader.dart';

void main() {
  const MethodChannel channel = MethodChannel('dev.inceptusp.fl_downloader');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'download') return 1;
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('download', () async {
    expect(
      await FlDownloader.download(
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      ),
      1,
    );
  });
}
