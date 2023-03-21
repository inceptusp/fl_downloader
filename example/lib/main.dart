import 'dart:async';

import 'package:fl_downloader/fl_downloader.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController fileNameController = TextEditingController(
    text: 'test.pdf',
  );
  final TextEditingController urlController = TextEditingController(
    text:
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
  );

  int progress = 0;
  dynamic downloadId;
  String? status;
  late StreamSubscription progressStream;

  @override
  void initState() {
    FlDownloader.initialize();
    progressStream = FlDownloader.progressStream.listen((event) {
      if (event.status == DownloadStatus.successful) {
        debugPrint('event.progress: ${event.progress}');
        setState(() {
          progress = event.progress;
          downloadId = event.downloadId;
          status = event.status.name;
        });
        // This is a way of auto-opening downloaded file right after a download is completed
        FlDownloader.openFile(filePath: event.filePath);
      } else if (event.status == DownloadStatus.running) {
        debugPrint('event.progress: ${event.progress}');
        setState(() {
          progress = event.progress;
          downloadId = event.downloadId;
          status = event.status.name;
        });
      } else if (event.status == DownloadStatus.failed) {
        debugPrint('event: $event');
        setState(() {
          progress = event.progress;
          downloadId = event.downloadId;
          status = event.status.name;
        });
      } else if (event.status == DownloadStatus.paused) {
        debugPrint('Download paused');
        setState(() {
          progress = event.progress;
          downloadId = event.downloadId;
          status = event.status.name;
        });
        // Here I am attaching the download progress to the download task again
        // after an paused status because the download task can be paused by
        // the system when the connection is lost or is waiting for a wifi
        // connection see https://developer.android.com/reference/android/app/DownloadManager#PAUSED_QUEUED_FOR_WIFI
        // for the possible reasons of a download task to be auto-paused by the
        // system (this applies to Windows too as the plugin sets the same suspension
        // policies for Windows downloads).
        Future.delayed(
          const Duration(milliseconds: 250),
          () => FlDownloader.attachDownloadProgress(event.downloadId),
        );
      } else if (event.status == DownloadStatus.pending) {
        debugPrint('Download pending');
        setState(() {
          progress = event.progress;
          downloadId = event.downloadId;
          status = event.status.name;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    progressStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FlDownloader example app'),
        ),
        body: Column(
          children: [
            if (progress > 0 && progress < 100)
              LinearProgressIndicator(
                value: progress / 100,
                color: Colors.orange,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  label: Text('URL'),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: fileNameController,
                decoration: const InputDecoration(
                  label: Text('File name'),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Download id: $downloadId\n'
              'Status: $status\n'
              'Progress: $progress%',
            ),
            const Spacer(),
          ],
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            /* FloatingActionButton(
              backgroundColor: Colors.green[200],
              child: const Icon(Icons.play_arrow),
              onPressed: () async {
                // This function is not currently implemented
              },
            ),
            const SizedBox(width: 10),
            FloatingActionButton(
              backgroundColor: Colors.amber[200],
              child: const Icon(Icons.pause),
              onPressed: () async {
                // This function is not currently implemented
              },
            ), */
            const SizedBox(width: 10),
            FloatingActionButton(
              backgroundColor: Colors.red[300],
              child: const Icon(Icons.close),
              onPressed: () async {
                final cancelList = [downloadId];
                final cancelled = await FlDownloader.cancel(cancelList);
                if (cancelled == cancelList.length) {
                  setState(() {
                    progress = 0;
                    downloadId = null;
                    status = 'All downloads cancelled';
                  });
                } else {
                  setState(() {
                    progress = 0;
                    downloadId = null;
                    status = 'Cancelled $cancelled downloads from the list';
                  });
                }
              },
            ),
            const SizedBox(width: 10),
            FloatingActionButton(
              child: const Icon(Icons.download_sharp),
              onPressed: () async {
                final permission = await FlDownloader.requestPermission();
                if (permission == StoragePermissionStatus.granted) {
                  await FlDownloader.download(
                    urlController.text,
                    fileName: fileNameController.text,
                  );
                } else {
                  debugPrint('Permission denied =(');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
