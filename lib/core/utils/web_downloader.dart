import 'dart:typed_data';
import 'web_downloader_stub.dart'
    if (dart.library.html) 'web_downloader_web.dart';

Future<void> downloadFileUniversal({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) =>
    downloadFileUniversalImpl(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
