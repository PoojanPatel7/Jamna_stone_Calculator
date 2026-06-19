import 'package:flutter/material.dart';
import '../../data/models/slab_models.dart';
import '../../services/storage_service.dart';
import 'slab_measurement_screen.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SlabBook> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.loadHistory();
    // Sort by newest first
    history.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _history = history;
    });
  }

  Future<void> _deleteBook(String id) async {
    await StorageService.deleteBook(id);
    _loadHistory();
  }

  Future<void> _renameBook(SlabBook book) {
    final controller = TextEditingController(text: book.name);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Book'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter new name'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  book.name = controller.text.trim();
                  await StorageService.saveBook(book);
                  _loadHistory();
                }
                Navigator.pop(context);
              }, 
              child: const Text('Save')
            ),
          ],
        );
      }
    );
  }

  pw.Document _buildPdfDocumentForBook(SlabBook book) {
    final pdf = pw.Document();
    
    final List<SlabEntry> expandedSlabs = [];
    for (var s in book.slabs) {
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
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(book.name, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Unit: ${book.unit}', style: pw.TextStyle(fontSize: 18)),
                ]
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.center,
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 16),
              headers: ['No.', 'Length', 'Width', 'Area'],
              data: expandedSlabs.map<List<String>>((s) {
                return [
                  '${s.slabNo}',
                  s.length.toString(),
                  s.width.toString(),
                  '${s.getArea(book.unit).toStringAsFixed(2)} ${book.unit}'
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Slabs: $totalQuantity', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Area: ${totalArea.toStringAsFixed(2)} ${book.unit}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ]
            )
          ];
        }
      )
    );
    return pdf;
  }

  Future<void> _deleteBookWithConfirmation(SlabBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Delete Book?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                const Text('Are you sure you want to delete this book? Please review the data below.'),
                const SizedBox(height: 16),
                Expanded(
                  child: PdfPreview(
                    build: (format) async {
                      final pdf = _buildPdfDocumentForBook(book);
                      return pdf.save();
                    },
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Confirm Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );

    if (confirm == true) {
      await StorageService.deleteBook(book.id);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book deleted successfully'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openBook(SlabBook book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SlabMeasurementScreen(loadedBook: book),
      ),
    ).then((_) => _loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Saved Books'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _history.isEmpty
          ? const Center(child: Text('No saved slab books found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final book = _history[index];
                int totalSlabs = book.slabs.fold(0, (sum, slab) => sum + slab.quantity);
                double totalArea = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
                
                return InkWell(
                  onTap: () => _openBook(book),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.amber.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.book_rounded, color: AppColors.amber),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(book.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('MMM dd, yyyy - hh:mm a').format(book.date)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: $totalSlabs | Area: ${totalArea.toStringAsFixed(2)} ${book.unit}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'rename') {
                              _renameBook(book);
                            } else if (value == 'export') {
                              _openBook(book);
                            } else if (value == 'delete') {
                              _deleteBookWithConfirmation(book);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'rename', child: Text('Rename')),
                            const PopupMenuItem(value: 'export', child: Text('Open & Export')),
                            const PopupMenuItem(
                              value: 'delete', 
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
