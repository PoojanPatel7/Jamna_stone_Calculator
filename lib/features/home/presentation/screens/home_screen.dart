import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../../../slabs/services/storage_service.dart';
import '../../../slabs/data/models/slab_models.dart';
import '../../../stock/services/stock_storage_service.dart';
import '../../../stock/data/models/stock_models.dart';
import '../../../../main.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../slabs/services/backup_service.dart';
import '../../../../core/utils/pdf_generator.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartMeasurement;
  final VoidCallback? onGoToStock;
  final bool isActive;
  
  const HomeScreen({
    super.key, 
    required this.onStartMeasurement, 
    this.onGoToStock,
    this.isActive = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalBooks = 0;
  double _totalAreaSaved = 0.0;
  
  List<StockEntry> _stockEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    // Load History Stats
    final history = await StorageService.loadHistory();
    double area = 0.0;
    for (var book in history) {
      for (var slab in book.slabs) {
        area += slab.getArea(book.unit);
      }
    }
    
    // Load Stock Stats
    final stock = await StockStorageService.loadStockEntries();
    
    if (mounted) {
      setState(() {
        _totalBooks = history.length;
        _totalAreaSaved = area;
        _stockEntries = stock;
        _isLoading = false;
      });
    }
  }

  Future<void> _startBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    
    final history = await StorageService.loadHistory();
    final stock = await StockStorageService.loadStockEntries();
    
    int unsyncedBooks = history.where((b) => !b.isSynced).length;
    int unsyncedStock = stock.where((e) => !e.isSynced).length;
    int totalBooks = history.length;
    int totalStock = stock.length;
    
    if (mounted) Navigator.pop(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        bool isConfirmed = false;
        bool isScanning = false;
        double progress = 0.0;
        bool isFinished = false;
        bool isError = false;
        String errorMessage = '';

        return StatefulBuilder(
          builder: (context, setState) {
            void startProcess() async {
              setState(() {
                isConfirmed = true;
                isScanning = true;
              });
              
              await Future.delayed(const Duration(milliseconds: 1500));
              if (mounted) setState(() => isScanning = false);
              
              try {
                await BackupService.syncToLocalFolder(
                  pdfGenerator: PdfGenerator.buildPdfDocumentForBook,
                  onProgress: (p) {
                    if (mounted) setState(() => progress = p);
                  },
                );
                if (mounted) {
                  this.setState(() {
                    _loadStats();
                  });
                  setState(() => isFinished = true);
                  
                  await Future.delayed(const Duration(milliseconds: 2500));
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    isFinished = true;
                    isError = true;
                    errorMessage = e.toString();
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
                            child: _buildBackupContent(
                              key: ValueKey('backup_${isConfirmed}_${isScanning}_${isFinished}_${isError}'),
                              isDark: isDark,
                              isConfirmed: isConfirmed,
                              isScanning: isScanning,
                              isFinished: isFinished,
                              isError: isError,
                              progress: progress,
                              errorMessage: errorMessage,
                              unsyncedBooks: unsyncedBooks,
                              unsyncedStock: unsyncedStock,
                              totalBooks: totalBooks,
                              totalStock: totalStock,
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

  Widget _buildBackupContent({
    required Key key,
    required bool isDark,
    required bool isConfirmed,
    required bool isScanning,
    required bool isFinished,
    required bool isError,
    required double progress,
    required String errorMessage,
    required int unsyncedBooks,
    required int unsyncedStock,
    required int totalBooks,
    required int totalStock,
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
          const Text('Backup Failed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
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
          const Text('Backup Complete', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 12),
          Text('All your data is securely stored locally.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200)),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${unsyncedBooks > 0 ? unsyncedBooks : "All"} Measurement Books Synced', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${unsyncedStock > 0 ? unsyncedStock : "All"} Stock Entries Synced', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                  ],
                ),
              ],
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
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
          Text(isScanning ? 'Scanning files...' : 'Syncing to Local Storage...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 12,
                width: isScanning ? 40 : (MediaQuery.of(context).size.width * 0.85 - 64) * progress,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ).animate(target: isScanning ? 1 : 0).slideX(begin: 0, end: 5, duration: 1.seconds, curve: Curves.easeInOut).then().slideX(begin: -5, end: 0, duration: 1.seconds, curve: Curves.easeInOut),
            ],
          ),
          const SizedBox(height: 16),
          Text(isScanning ? 'Analyzing differential changes...' : '${(progress * 100).toStringAsFixed(0)}% Complete', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      );
    }

    // Default Initial State
    bool hasItemsToSync = unsyncedBooks > 0 || unsyncedStock > 0;
    
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
          child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 24),
        Text('Secure Backup', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Differential sync active. Only modified items will be saved locally.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200)),
          child: Column(
            children: [
              _buildStatRow('Measurement Books', '$unsyncedBooks / $totalBooks', Icons.book_rounded, isDark),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _buildStatRow('Stock Entries', '$unsyncedStock / $totalStock', Icons.inventory_2_rounded, isDark),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasItemsToSync ? onStart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white, 
              disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
              disabledForegroundColor: isDark ? Colors.white54 : Colors.black38,
              padding: const EdgeInsets.symmetric(vertical: 18), 
              elevation: hasItemsToSync ? 8 : 0,
              shadowColor: Colors.blue.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            child: Text(hasItemsToSync ? 'Start Sync' : 'Everything is Synced!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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

  Future<void> _startImport() async {
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
                  this.setState(() {
                    _loadStats();
                  });
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
                              key: ValueKey('import_${isConfirmed}_${isScanning}_${isFinished}_${isError}'),
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

  Widget _buildFeatureCard(IconData icon, String textKey, Color iconColor) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const Spacer(),
          Text(
            textKey.tr,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.3,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStockDashboard() {
    int marbleSlabs = 0;
    double marbleArea = 0.0;
    int graniteSlabs = 0;
    double graniteArea = 0.0;

    for (var entry in _stockEntries) {
      if (entry.blockTypeName == 'Marble') {
        marbleSlabs += entry.totalSlabCount;
        marbleArea += entry.estimatedArea;
      } else if (entry.blockTypeName == 'Granite') {
        graniteSlabs += entry.totalSlabCount;
        graniteArea += entry.estimatedArea;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Available Stock',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.blue : Theme.of(context).primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: isDark ? Colors.blue : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ).animate().fade().slideX(begin: 0.1),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStockSummaryCard(
                title: 'Marble',
                icon: Icons.layers_outlined,
                slabs: marbleSlabs,
                area: marbleArea,
                color: const Color(0xFF009688), // Teal
                bgColor: const Color(0xFFE0F2F1),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildStockSummaryCard(
                title: 'Granite',
                icon: Icons.filter_none_rounded,
                slabs: graniteSlabs,
                area: graniteArea,
                color: const Color(0xFFE91E63), // Pink
                bgColor: const Color(0xFFFCE4EC),
                isDark: isDark,
              ),
            ],
          ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildStockSummaryCard({
    required String title,
    required IconData icon,
    required int slabs,
    required double area,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6)),
          ],
          border: Border.all(color: isDark ? Colors.white12 : bgColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? color.withOpacity(0.2) : bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${area.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.1,
              ),
            ),
            Text(
              'Total SqFt',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.2) : bgColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$slabs Slabs',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
              ],
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.language_rounded, color: isDark ? Colors.white : Colors.black87),
              tooltip: 'Change Language',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (String lang) {
                AppTranslations.currentLocale.value = lang;
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'en', child: Text('English')),
                const PopupMenuItem<String>(value: 'hi', child: Text('हिंदी')),
                const PopupMenuItem<String>(value: 'gu', child: Text('ગુજરાતી')),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
              ],
            ),
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.blue : Colors.indigo),
              onPressed: () {
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                      : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.architecture_rounded, color: isDark ? Colors.blue : primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Professional Calculator',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ).animate().fade().slideY(begin: 0.2),
                  const SizedBox(height: 24),
                  Text(
                    'app_title'.tr,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                  const SizedBox(height: 16),
                  Text(
                    'about_desc'.tr,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 40),
                  
                  // Main Call to Action
                  Center(
                    child: ElevatedButton(
                      onPressed: widget.onStartMeasurement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.blue : Colors.black87,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        elevation: 10,
                        shadowColor: (isDark ? Colors.blue : Colors.black).withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_box_rounded, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            'start_measuring'.tr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: 300.ms).scale(begin: const Offset(0.8, 0.8)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Available Stock Dashboard
            if (widget.onGoToStock != null)
              GestureDetector(
                onTap: widget.onGoToStock,
                child: _buildStockDashboard(),
              )
            else
              _buildStockDashboard(),
            
            const SizedBox(height: 40),
            
            // Features / Guide Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Text(
                    'app_guide'.tr,
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.swipe, color: Colors.grey.shade400),
                ],
              ),
            ).animate().fade(delay: 400.ms).slideX(begin: 0.1),
            
            const SizedBox(height: 20),
            
            SizedBox(
              height: 200,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFeatureCard(Icons.play_circle_fill_rounded, 'guide_1', Colors.blue),
                  _buildFeatureCard(Icons.edit_document, 'guide_2', Colors.orange),
                  _buildFeatureCard(Icons.layers_rounded, 'guide_3', Colors.purple),
                  _buildFeatureCard(Icons.exposure_plus_1_rounded, 'guide_4', Colors.green),
                  _buildFeatureCard(Icons.dashboard_customize_rounded, 'guide_5', Colors.red),
                  _buildFeatureCard(Icons.history_rounded, 'guide_6', Colors.teal),
                  _buildFeatureCard(Icons.share_rounded, 'guide_7', Colors.indigo),
                ].animate(interval: 50.ms).fade(delay: 500.ms).slideX(begin: 0.2),
              ),
            ),
            
            const SizedBox(height: 48),

            // Backup & Restore Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _startBackup,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.blue : Colors.blue.shade600).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.cloud_upload_rounded, color: Colors.blue),
                            ),
                            const SizedBox(height: 12),
                            const Text('Export Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _startImport,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.green : Colors.green.shade600).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.cloud_download_rounded, color: Colors.green),
                            ),
                            const SizedBox(height: 12),
                            const Text('Import Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 48),
            
            // Footer (BHIM UPI Style)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 100, left: 16, right: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
                border: Border(
                  top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTrustBadge(
                        icon: Icons.gpp_good_rounded, 
                        title: '100% SECURE', 
                        subtitle: 'Local Storage',
                        isDark: isDark,
                      ),
                      Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.black12),
                      _buildTrustBadge(
                        icon: Icons.favorite_rounded, 
                        title: 'MADE IN INDIA', 
                        subtitle: 'With Love',
                        isDark: isDark,
                      ),
                      Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.black12),
                      _buildTrustBadge(
                        icon: Icons.architecture_rounded, 
                        title: 'PRECISION', 
                        subtitle: 'Measurements',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'POWERED BY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PANCHASARA POOJAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 700.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge({required IconData icon, required String title, required String subtitle, required bool isDark}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isDark ? Colors.white54 : Colors.black54, size: 28),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}
