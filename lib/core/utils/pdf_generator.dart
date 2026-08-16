import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/slabs/data/models/slab_models.dart';

class PdfGenerator {
  static pw.Document buildPdfDocumentForBook(SlabBook book) {
    final pdf = pw.Document();
    
    final List<SlabEntry> expandedSlabs = [];
    for (var s in book.slabs) {
      if (s.quantity <= 0 || s.length <= 0 || s.width <= 0) continue;
      for (int i = 0; i < s.quantity; i++) {
        expandedSlabs.add(SlabEntry(
          slabNo: s.slabNo + i,
          length: s.length,
          width: s.width,
          quantity: 1,
        ));
      }
    }
    
    final int totalQuantity = book.slabs.fold(0, (sum, slab) => sum + slab.quantity);
    final double totalArea = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
    
    if (expandedSlabs.isEmpty) {
      pdf.addPage(pw.Page(
        pageTheme: pw.PageTheme(
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        build: (context) => pw.Center(child: pw.Text('No Data'))
      ));
      return pdf;
    }

    for (int i = 0; i < expandedSlabs.length; i += 100) {
      final chunk = expandedSlabs.sublist(i, i + 100 > expandedSlabs.length ? expandedSlabs.length : i + 100);
      final leftChunk = chunk.sublist(0, chunk.length > 50 ? 50 : chunk.length);
      final rightChunk = chunk.length > 50 ? chunk.sublist(50) : <SlabEntry>[];
      
      final bool isLastPage = (i + 100) >= expandedSlabs.length;
      final int pageTotalQuantity = chunk.length;
      final double pageTotalArea = chunk.fold<double>(0.0, (sum, slab) => sum + slab.getArea(book.unit));

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            buildBackground: (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColors.white),
            ),
          ),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Center(
                        child: pw.Text('ESTIMATED SHEET', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Party: ${book.partyName ?? "N/A"}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Plate: ${(book.numberPlate != null && book.numberPlate!.isNotEmpty ? book.numberPlate : "N/A")}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Granite: ${book.graniteName ?? "N/A"}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Date: ${book.date.day.toString().padLeft(2, '0')}/${book.date.month.toString().padLeft(2, '0')}/${book.date.year}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                    ]
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: _buildPdfTable(context, leftChunk, book.unit)),
                      pw.SizedBox(width: 20),
                      pw.Expanded(child: rightChunk.isNotEmpty ? _buildPdfTable(context, rightChunk, book.unit) : pw.Container()),
                    ]
                  )
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Page Slabs: $pageTotalQuantity', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('Page Area: ${pageTotalArea.toStringAsFixed(2)} ${book.unit}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ]
                ),
                if (isLastPage) ...[
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Slabs: $totalQuantity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Area: ${totalArea.toStringAsFixed(2)} ${book.unit}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                ],
                pw.SizedBox(height: 10),
              ]
            );
          }
        )
      );
    }
    return pdf;
  }

  static pw.Widget _buildPdfTable(pw.Context context, List<SlabEntry> data, String unit) {
    return pw.TableHelper.fromTextArray(
      context: context,
      cellAlignment: pw.Alignment.center,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      headers: ['No.', 'L', 'W', 'Area'],
      data: data.map<List<String>>((s) {
        return [
          '${s.slabNo}',
          s.length.toString(),
          s.width.toString(),
          '${s.getArea(unit).toStringAsFixed(2)} $unit'
        ];
      }).toList(),
    );
  }
}
