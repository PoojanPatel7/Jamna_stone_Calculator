import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

class PdfShareHelper {
  /// Directly shares a PDF document with the exact specified file name.
  /// On mobile devices (iOS Safari & Android), this opens the native system Share Sheet
  /// (WhatsApp, AirDrop, Messages, Mail, etc.) directly WITHOUT downloading the file first.
  static Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final xFile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: filename,
      );

      final result = await Share.shareXFiles(
        [xFile],
        subject: filename,
        text: filename,
      );
      
      debugPrint('[PdfShareHelper] Direct PDF share completed with status: ${result.status}');
    } catch (e) {
      debugPrint('[PdfShareHelper] Direct shareXFiles encountered error ($e), falling back to Printing.sharePdf');
      try {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } catch (err) {
        debugPrint('[PdfShareHelper] Fallback sharePdf error: $err');
      }
    }
  }
}
