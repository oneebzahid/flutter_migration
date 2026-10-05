import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

/// Hands a generated file to the user: a browser download on web, a save
/// dialog / share sheet on desktop and mobile.
abstract interface class FileDownloader {
  Future<void> save({
    required String fileName,
    required String extension,
    required Uint8List bytes,
  });
}

class PlatformFileDownloader implements FileDownloader {
  const PlatformFileDownloader();

  @override
  Future<void> save({
    required String fileName,
    required String extension,
    required Uint8List bytes,
  }) async {
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: extension,
      mimeType: switch (extension) {
        'xlsx' => MimeType.microsoftExcel,
        'pdf' => MimeType.pdf,
        _ => MimeType.other,
      },
    );
  }
}

/// App-wide downloader. Tests replace [instance] with a fake.
abstract final class AppFileDownloader {
  static FileDownloader instance = const PlatformFileDownloader();
}
