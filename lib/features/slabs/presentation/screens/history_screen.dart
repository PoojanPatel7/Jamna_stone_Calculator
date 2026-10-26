import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/slab_models.dart';
import '../../services/storage_service.dart';
import 'slab_measurement_screen.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/app_translations.dart';
import '../../services/backup_service.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../stock/data/models/stock_models.dart';
import '../../../stock/services/stock_storage_service.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class HistoryScreen extends StatefulWidget {
  final Function(SlabBook) onBookOpened;
  final VoidCallback onNewBook;
  
  const HistoryScreen({super.key, required this.onBookOpened, required this.onNewBook});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SlabBook> _history = [];
  bool _isBackingUp = false;
  double _backupProgress = 0.0;

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

  Future<void> _editBookDetails(SlabBook book) {
    final nameController = TextEditingController(text: book.name);
    final partyController = TextEditingController(text: book.partyName ?? '');
    final graniteController = TextEditingController(text: book.graniteName ?? '');
    final plateController = TextEditingController(text: book.numberPlate ?? '');
    DateTime selectedDate = book.date;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Book Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Book Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: partyController,
                      decoration: const InputDecoration(labelText: 'Party Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: graniteController,
                      decoration: const InputDecoration(labelText: 'Granite/Marble Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plateController,
                      decoration: const InputDecoration(labelText: 'Number Plate (Optional)'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date', style: TextStyle(fontSize: 14)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      book.name = nameController.text.trim();
                      book.partyName = partyController.text.trim().isEmpty ? null : partyController.text.trim();
                      book.graniteName = graniteController.text.trim().isEmpty ? null : graniteController.text.trim();
                      book.numberPlate = plateController.text.trim().isEmpty ? null : plateController.text.trim();
                      book.date = selectedDate;
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
    );
  }

  Future<void> _detachBlock(SlabBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detach Block?'),
        content: const Text('This will unlink the block from this book and restore the consumed slabs back into your available stock. Do you want to continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Detach')
          ),
        ],
      ),
    );

    if (confirm == true) {
      book.linkedStockId = null;
      book.linkedBlockDisplay = null;
      await StorageService.saveBook(book);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block detached and stock restored successfully!')),
        );
      }
    }
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
                      final pdf = PdfGenerator.buildPdfDocumentForBook(book);
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
    widget.onBookOpened(book);
  }

  Future<void> _startBackup() async {
    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.0;
    });

    try {
      await BackupService.syncToLocalFolder(
        pdfGenerator: PdfGenerator.buildPdfDocumentForBook,
        onProgress: (progress) {
          setState(() {
            _backupProgress = progress;
          });
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup successful!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _startRestore() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    
    final dbMap = await BackupService.getBackupData();
    if (mounted) Navigator.pop(context); // close loading
    
    if (dbMap == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backup found.')));
      return;
    }
    
    int backupBooksCount = 0;
    int backupStockCount = 0;
    
    if (dbMap.containsKey('history')) {
      backupBooksCount = (dbMap['history'] as List).length;
    }
    if (dbMap.containsKey('stockEntries')) {
      backupStockCount = (dbMap['stockEntries'] as List).length;
    }
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        bool isConfirmed = false;
        bool isScanning = false;
        bool isFinished = false;
        bool isError = false;

        return StatefulBuilder(
          builder: (context, setState) {
            void startProcess() async {
              setState(() {
                isConfirmed = true;
                isScanning = true;
              });
              
              await Future.delayed(const Duration(milliseconds: 1500));
              if (mounted) setState(() => isScanning = false);
              
              final success = await BackupService.restoreFromLocalFolder(dbMap);
              
              if (mounted) {
                if (success) {
                  await _loadHistory();
                  setState(() => isFinished = true);
                  
                  await Future.delayed(const Duration(milliseconds: 2500));
                  if (mounted) {
                    Navigator.pop(context);
                  }
                } else {
                  setState(() {
                    isFinished = true;
                    isError = true;
                  });
                }
              }
            }
            
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            return PopScope(
              canPop: false,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      constraints: BoxConstraints(
                        maxWidth: 400,
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, spreadRadius: 5, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _buildImportContent(
                              key: ValueKey('restore_${isConfirmed}_${isScanning}_${isFinished}_${isError}'),
                              isDark: isDark,
                              isConfirmed: isConfirmed,
                              isScanning: isScanning,
                              isFinished: isFinished,
                              isError: isError,
                              backupBooksCount: backupBooksCount,
                              backupStockCount: backupStockCount,
                              onStart: startProcess,
                              onClose: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildImportContent({
    required Key key,
    required bool isDark,
    required bool isConfirmed,
    required bool isScanning,
    required bool isFinished,
    required bool isError,
    required int backupBooksCount,
    required int backupStockCount,
    required VoidCallback onStart,
    required VoidCallback onClose,
  }) {
    if (isError) {
      return Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 56)
                .animate().shake(duration: 400.ms),
          ),
          const SizedBox(height: 24),
          const Text('Import Failed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          Text('An error occurred while loading data.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200, foregroundColor: isDark ? Colors.white : Colors.black, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      );
    }

    if (isFinished) {
      return Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64)
                .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          ),
          const SizedBox(height: 24),
          const Text('Data Imported!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 12),
          Text('Your local storage is now synced with the backup.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      );
    }

    if (isScanning || isConfirmed) {
      return Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
            child: isScanning 
                ? const Icon(Icons.manage_search_rounded, color: Colors.blue, size: 56).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.1, duration: 600.ms)
                : const Icon(Icons.cloud_sync_rounded, color: Colors.blue, size: 56).animate(onPlay: (controller) => controller.repeat()).rotate(duration: 2.seconds),
          ),
          const SizedBox(height: 32),
          Text(isScanning ? 'Scanning for missing data...' : 'Importing data...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(minHeight: 12),
          ),
        ],
      );
    }

    // Default Initial State
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 24),
        Text('Load Backup Data', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Only missing items will be imported to prevent duplicates.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200)),
          child: Column(
            children: [
              _buildStatRow('Books in Backup', '$backupBooksCount', Icons.book_rounded, isDark),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _buildStatRow('Stock in Backup', '$backupStockCount', Icons.inventory_2_rounded, isDark),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white, 
              padding: const EdgeInsets.symmetric(vertical: 18), 
              elevation: 8,
              shadowColor: Colors.blue.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            child: const Text('Confirm Load Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onClose,
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStatRow(String title, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500, fontSize: 15))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: value.startsWith('0 ') ? (isDark ? Colors.white38 : Colors.black38) : Colors.orange.shade600)),
      ],
    );
  }

  Future<void> _showComparePopup(SlabBook book) async {
    if (book.linkedStockId == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final stockEntry = await StockStorageService.getStockEntry(book.linkedStockId!);
    final linkedBooks = await StorageService.getBooksForStockId(book.linkedStockId!);
    
    if (mounted) Navigator.pop(context); // close loading

    if (stockEntry == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock block not found. It may have been deleted.')),
        );
      }
      return;
    }

    // Calculate totals
    int thisBookSlabs = book.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
    double thisBookArea = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));

    int allBooksSlabs = 0;
    double allBooksArea = 0;
    for (var b in linkedBooks) {
      allBooksSlabs += b.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
      allBooksArea += b.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(b.unit));
    }

    int remainingSlabs = stockEntry.totalSlabCount - allBooksSlabs;
    double remainingArea = stockEntry.estimatedArea - allBooksArea;

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimText = (stockEntry.height > 0 || stockEntry.width > 0)
        ? ' • Size: ${stockEntry.height % 1 == 0 ? stockEntry.height.toInt() : stockEntry.height}×${stockEntry.width % 1 == 0 ? stockEntry.width.toInt() : stockEntry.width}'
        : '';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.lightBlueAccent, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stock vs Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(
                                book.linkedBlockDisplay ?? stockEntry.blockName,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Original Stock
                  _buildCompareSection(
                    isDark: isDark,
                    icon: Icons.inventory_2_rounded,
                    title: 'Original Stock',
                    color: Colors.blue,
                    slabs: stockEntry.totalSlabCount,
                    area: stockEntry.estimatedArea,
                    subtitle: '${stockEntry.blockTypeName} • ${stockEntry.isPolished ? "Polished" : "Unpolished"}$dimText',
                  ),
                  const SizedBox(height: 12),

                  // This Book
                  _buildCompareSection(
                    isDark: isDark,
                    icon: Icons.description_rounded,
                    title: 'This Book',
                    color: Colors.orange,
                    slabs: thisBookSlabs,
                    area: thisBookArea,
                    subtitle: book.name,
                  ),
                  const SizedBox(height: 12),

                  // All Books on this Block
                  if (linkedBooks.length > 1) ...[
                    _buildCompareSection(
                      isDark: isDark,
                      icon: Icons.library_books_rounded,
                      title: 'All Books (${linkedBooks.length})',
                      color: Colors.purple,
                      slabs: allBooksSlabs,
                      area: allBooksArea,
                      subtitle: 'Total consumed from all linked books',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Remaining
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: remainingArea > 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: remainingArea > 0
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              remainingArea > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: remainingArea > 0 ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              remainingArea > 0 ? 'Remaining Stock' : 'Fully Sold',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: remainingArea > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text('Slabs', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${remainingSlabs < 0 ? 0 : remainingSlabs}',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: remainingArea > 0 ? Colors.green : Colors.red),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.grey.shade200),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('Area', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(remainingArea < 0 ? 0 : remainingArea).toStringAsFixed(1)} SqFt',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: remainingArea > 0 ? Colors.green : Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompareSection({
    required bool isDark,
    required IconData icon,
    required String title,
    required Color color,
    required int slabs,
    required double area,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Slabs', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold)),
                    Text('$slabs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              Container(width: 1, height: 24, color: isDark ? Colors.white12 : Colors.grey.shade200),
              Expanded(
                child: Column(
                  children: [
                    Text('Area', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold)),
                    Text('${area.toStringAsFixed(1)} SqFt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markLinkedStockAsSold(SlabBook book) async {
    if (book.linkedStockId == null) return;
    
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Stock as Sold?'),
        content: const Text('This will manually mark the linked stock block as fully sold, even if it has remaining area. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as Sold'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marking stock as sold...')),
      );
    }
    
    await StockStorageService.forceMarkAsSold(book.linkedStockId!, true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock marked as sold successfully')),
      );
    }
  }

  Future<void> _linkToStockBlock(SlabBook book) async {
    final availableEntries = await StockStorageService.getAvailableStockEntries();
    
    if (availableEntries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available stock blocks to link.')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selectedEntry = await showDialog<StockEntry>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Link to Stock Block'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableEntries.length,
              itemBuilder: (context, index) {
                final entry = availableEntries[index];
                final display = entry.blockNumber.isNotEmpty
                    ? '${entry.blockName} (#${entry.blockNumber}) - ${entry.blockTypeName}'
                    : '${entry.blockName} - ${entry.blockTypeName}';
                    
                final dimSubtitle = (entry.height > 0 || entry.width > 0)
                    ? ' • ${entry.height % 1 == 0 ? entry.height.toInt() : entry.height}×${entry.width % 1 == 0 ? entry.width.toInt() : entry.width}'
                    : '';
                return ListTile(
                  title: Text(display),
                  subtitle: Text('${entry.totalSlabCount} slabs • ${entry.estimatedArea.toStringAsFixed(1)} sqft$dimSubtitle'),
                  onTap: () => Navigator.pop(context, entry),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedEntry != null) {
      book.linkedStockId = selectedEntry.id;
      book.linkedBlockDisplay = selectedEntry.blockNumber.isNotEmpty
          ? '${selectedEntry.blockName} (#${selectedEntry.blockNumber})'
          : selectedEntry.blockName;
          
      await StorageService.saveBook(book);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Linked successfully.')),
        );
      }
      _loadHistory();
    }
  }

  Future<void> _shareBook(SlabBook book) async {
    final pdf = PdfGenerator.buildPdfDocumentForBook(book);
    final bytes = await pdf.save();
    
    String baseName = '';
    if (book.partyName != null && book.partyName!.isNotEmpty) {
      baseName += book.partyName!;
    }
    if (book.graniteName != null && book.graniteName!.isNotEmpty) {
      if (baseName.isNotEmpty) baseName += '-';
      baseName += book.graniteName!;
    }
    if (baseName.isEmpty) {
      baseName = 'Book_${book.id}';
    }
    final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    
    await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('history'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _history.isEmpty
          ? const Center(child: Text('No saved slab books found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final book = _history[index];
                int totalSlabs = book.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
                double totalArea = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
                
                return InkWell(
                  onTap: () => _openBook(book),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withOpacity(0.95)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.lightBlueAccent, Colors.blue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          book.name, 
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (book.isSynced)
                                        const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20)
                                      else
                                        const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy • hh:mm a').format(book.date),
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editBookDetails(book);
                                } else if (value == 'export') {
                                  _openBook(book);
                                } else if (value == 'share') {
                                  _shareBook(book);
                                } else if (value == 'delete') {
                                  _deleteBookWithConfirmation(book);
                                } else if (value == 'mark_sold') {
                                  _markLinkedStockAsSold(book);
                                } else if (value == 'link_stock') {
                                  _linkToStockBlock(book);
                                } else if (value == 'detach_stock') {
                                  _detachBlock(book);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 8), Text('Edit Details')])),
                                const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_rounded, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Share PDF')])),
                                const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.open_in_new_rounded, size: 20), SizedBox(width: 8), Text('Open & Export')])),
                                if (book.linkedStockId != null) ...[
                                  const PopupMenuItem(value: 'mark_sold', child: Row(children: [Icon(Icons.check_circle_outline_rounded, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Mark Stock as Sold')])),
                                  const PopupMenuItem(value: 'detach_stock', child: Row(children: [Icon(Icons.link_off_rounded, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Detach Block')])),
                                ],
                                if (book.linkedStockId == null)
                                  const PopupMenuItem(value: 'link_stock', child: Row(children: [Icon(Icons.link_rounded, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Link to Stock Block')])),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Slabs', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('$totalSlabs', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              Container(width: 1, height: 30, color: Theme.of(context).dividerColor.withOpacity(0.2)),
                              Column(
                                children: [
                                  const Text('Total Area', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('${totalArea.toStringAsFixed(2)} ${book.unit}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if ((book.partyName != null && book.partyName!.isNotEmpty) || (book.numberPlate != null && book.numberPlate!.isNotEmpty)) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (book.partyName != null && book.partyName!.isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(book.partyName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                              if (book.numberPlate != null && book.numberPlate!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions_car_rounded, size: 12, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        book.numberPlate!,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        ],
                        // Stock block link badge + Compare button
                        if (book.linkedStockId != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inventory_2_rounded, size: 14, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          book.linkedBlockDisplay ?? 'Linked Block',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => _showComparePopup(book),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.compare_arrows_rounded, size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Compare', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_isBackingUp)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.blue),
                        const SizedBox(height: 16),
                        Text('Backing up data...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        const SizedBox(height: 8),
                        Text('${(_backupProgress * 100).toStringAsFixed(0)}% Complete', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await StorageService.saveDraft([], 'inch');
            widget.onNewBook();
          },
          icon: const Icon(Icons.add_rounded),
          label: Text('new_book'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
