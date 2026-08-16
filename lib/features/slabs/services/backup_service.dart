import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';
import '../../stock/services/stock_storage_service.dart';
import '../data/models/slab_models.dart';
import '../../stock/data/models/stock_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';

class BackupService {
  /// Requests storage permissions for Android.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Gets the persistent backup directory.
  static Future<Directory?> getBackupDirectory() async {
    if (!await requestStoragePermission()) return null;
    
    final dir = Directory('/storage/emulated/0/Documents/Jamna Stone Backup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final pdfDir = Directory('${dir.path}/PDFs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    
    return dir;
  }

  /// Syncs unsynced data to the local persistent folder.
  static Future<void> syncToLocalFolder({
    required pw.Document Function(SlabBook) pdfGenerator,
    required void Function(double) onProgress,
  }) async {
    final backupDir = await getBackupDirectory();
    if (backupDir == null) {
      throw Exception('Storage permission denied.');
    }
    
    onProgress(0.05);
    final history = await StorageService.loadHistory();
    final stockEntries = await StockStorageService.loadStockEntries();
    final blockNames = await StockStorageService.loadBlockNames();
    
    // Find unsynced items
    final unsyncedBooks = history.where((b) => !b.isSynced).toList();
    final unsyncedStock = stockEntries.where((e) => !e.isSynced).toList();
    
    final int totalToProcess = unsyncedBooks.length;
    
    // 1. Generate PDFs for unsynced history records
    for (int i = 0; i < totalToProcess; i++) {
      final book = unsyncedBooks[i];
      final pdf = pdfGenerator(book);
      final pdfBytes = await pdf.save();
      
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
      final pdfFile = File('${backupDir.path}/PDFs/$safeName.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      
      // Mark as synced
      book.isSynced = true;
      
      onProgress(0.1 + (0.7 * ((i + 1) / (totalToProcess > 0 ? totalToProcess : 1))));
    }
    
    if (totalToProcess == 0) {
      onProgress(0.8);
    }
    
    // Mark stock as synced
    for (var entry in unsyncedStock) {
      entry.isSynced = true;
    }
    
    // 2. Serialize Database to the persistent folder
    final dbMap = {
      'history': history.map((e) => e.toJson()).toList(),
      'stockEntries': stockEntries.map((e) => e.toJson()).toList(),
      'blockNames': blockNames,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final dbFile = File('${backupDir.path}/database.json');
    await dbFile.writeAsString(jsonEncode(dbMap));
    onProgress(0.9);
    
    // 3. Update local storage so the app remembers they are synced
    await StorageService.writeHistory(history);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stock_entries_data', jsonEncode(stockEntries.map((e) => e.toJson()).toList()));
    
    onProgress(1.0);
  }
  
  /// Reads the backup file from local storage and returns raw maps to parse.
  static Future<Map<String, dynamic>?> getBackupData() async {
    try {
      final backupDir = await getBackupDirectory();
      if (backupDir == null) return null;
      
      final dbFile = File('${backupDir.path}/database.json');
      if (!await dbFile.exists()) return null;
      
      final dbContent = await dbFile.readAsString();
      return jsonDecode(dbContent) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to read backup data: $e');
      return null;
    }
  }

  /// Restores data from the provided map by strictly performing a differential merge.
  static Future<bool> restoreFromLocalFolder(Map<String, dynamic> dbMap) async {
    try {
      // Parse History
      if (dbMap.containsKey('history')) {
        final List historyList = dbMap['history'];
        final backupHistory = historyList.map((e) => SlabBook.fromJson(e as Map<String, dynamic>)).toList();
        
        final currentHistory = await StorageService.loadHistory();
        bool historyChanged = false;
        
        for (var backupBook in backupHistory) {
          final exists = currentHistory.any((b) => b.id == backupBook.id);
          if (!exists) {
            currentHistory.add(backupBook);
            historyChanged = true;
          }
        }
        
        if (historyChanged) {
          await StorageService.writeHistory(currentHistory);
        }
      }
      
      // Parse Stock
      if (dbMap.containsKey('stockEntries')) {
        final List stockList = dbMap['stockEntries'];
        final backupStock = stockList.map((e) => StockEntry.fromJson(e as Map<String, dynamic>)).toList();
        
        final currentStock = await StockStorageService.loadStockEntries();
        bool stockChanged = false;
        
        for (var stock in backupStock) {
          final exists = currentStock.any((e) => e.id == stock.id);
          if (!exists) {
            currentStock.add(stock);
            stockChanged = true;
          }
        }
        
        if (stockChanged) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('stock_entries_data', jsonEncode(currentStock.map((e) => e.toJson()).toList()));
        }
      }
      
      if (dbMap.containsKey('blockNames')) {
        final List blockNames = dbMap['blockNames'];
        for (var name in blockNames) {
          await StockStorageService.saveBlockName(name.toString());
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}
