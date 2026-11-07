import 'dart:typed_data';

Future<void> downloadFileUniversalImpl({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  // No-op on native platforms (handled by native filesystem)
}
