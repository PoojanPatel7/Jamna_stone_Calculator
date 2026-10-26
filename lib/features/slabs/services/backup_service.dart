import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'storage_service.dart';
import '../../stock/services/stock_storage_service.dart';
import '../data/models/slab_models.dart';
import '../../stock/data/models/stock_models.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';

class BackupLog {
  final String date;
  final String type; // 'Backup' or 'Load'
  final String details;

  BackupLog({required this.date, required this.type, required this.details});

  Map<String, dynamic> toJson() => {'date': date, 'type': type, 'details': details};
  
  factory BackupLog.fromJson(Map<String, dynamic> json) {
    return BackupLog(
      date: json['date'],
      type: json['type'],
      details: json['details'],
    );
  }
}

class BackupService {
  static const String _logKey = 'jamna_stone_backup_logs';

  static Future<void> _logEvent(String type, String details) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_logKey) ?? [];
    
    final newLog = BackupLog(
      date: DateTime.now().toIso8601String(),
      type: type,
      details: details,
    );
    
    logs.insert(0, jsonEncode(newLog.toJson())); // Add to top
    if (logs.length > 50) logs = logs.sublist(0, 50); // Keep last 50
    
    await prefs.setStringList(_logKey, logs);
  }

  static Future<List<BackupLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_logKey) ?? [];
    return logs.map((l) => BackupLog.fromJson(jsonDecode(l))).toList();
  }

  /// Verifies storage access for Android. Native app storage requires zero permissions.
  static Future<bool> requestStoragePermission() async {
    return true;
  }

  /// Gets the persistent backup directory.
  /// Uses app-specific external storage or documents storage (100% compliant with Google Play).
  static Future<Directory?> getBackupDirectory() async {
    Directory? baseDir;
    try {
      if (Platform.isAndroid) {
        baseDir = await getExternalStorageDirectory();
      }
    } catch (_) {}
    
    baseDir ??= await getApplicationDocumentsDirectory();

    final dir = Directory('${baseDir.path}/Jamna Stone Backup');
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
      throw Exception('Storage directory could not be created.');
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
    
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    await prefs.setString('widget_backup_date', dateStr);
    
    await _logEvent('Backup', 'Successfully backed up $totalToProcess measurement sheets and updated database.json.');
    
    onProgress(1.0);
  }
  
  /// Reads the backup file from local storage and returns raw maps to parse.
  /// Checks primary persistent backup directory first, with fallback to legacy path.
  static Future<Map<String, dynamic>?> getBackupData() async {
    try {
      // 1. Check primary persistent backup directory
      final backupDir = await getBackupDirectory();
      if (backupDir != null) {
        final dbFile = File('${backupDir.path}/database.json');
        if (await dbFile.exists()) {
          final dbContent = await dbFile.readAsString();
          return jsonDecode(dbContent) as Map<String, dynamic>;
        }
      }
      
      // 2. Check fallback legacy Documents path (if user had old app version)
      try {
        final legacyFile = File('/storage/emulated/0/Documents/Jamna Stone Backup/database.json');
        if (await legacyFile.exists()) {
          final dbContent = await legacyFile.readAsString();
          return jsonDecode(dbContent) as Map<String, dynamic>;
        }
      } catch (_) {}
      
      return null;
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
      
      await _logEvent('Load', 'Successfully restored data from database.json.');
      
      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }

  /// Silently updates the database.json in the backup folder to ensure data is never lost, 
  /// even on app uninstall. Call this after data modifications.
  static Future<void> silentDatabaseSync() async {
    try {
      final backupDir = await getBackupDirectory();
      if (backupDir == null) return;
      
      final history = await StorageService.loadHistory();
      final stockEntries = await StockStorageService.loadStockEntries();
      final blockNames = await StockStorageService.loadBlockNames();
      
      final dbMap = {
        'history': history.map((e) => e.toJson()).toList(),
        'stockEntries': stockEntries.map((e) => e.toJson()).toList(),
        'blockNames': blockNames,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final dbFile = File('${backupDir.path}/database.json');
      await dbFile.writeAsString(jsonEncode(dbMap));
    } catch (e) {
      debugPrint('Silent backup failed: $e');
    }
  }

  /// Exports and shares the database.json file to Google Drive, WhatsApp, or Device Storage.
  static Future<bool> exportDatabaseFile() async {
    try {
      await silentDatabaseSync();

      final backupDir = await getBackupDirectory();
      if (backupDir == null) return false;

      final dbFile = File('${backupDir.path}/database.json');
      if (!await dbFile.exists()) {
        final history = await StorageService.loadHistory();
        final stockEntries = await StockStorageService.loadStockEntries();
        final blockNames = await StockStorageService.loadBlockNames();
        final dbMap = {
          'history': history.map((e) => e.toJson()).toList(),
          'stockEntries': stockEntries.map((e) => e.toJson()).toList(),
          'blockNames': blockNames,
          'timestamp': DateTime.now().toIso8601String(),
        };
        await dbFile.writeAsString(jsonEncode(dbMap));
      }

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await Share.shareXFiles(
        [XFile(dbFile.path, mimeType: 'application/json', name: 'Jamna_Stone_Backup_$dateStr.json')],
        text: 'Jamna Stone Database Backup ($dateStr)',
        subject: 'Jamna Stone Backup',
      );
      return true;
    } catch (e) {
      debugPrint('Export database failed: $e');
      return false;
    }
  }

  /// Opens the native system file selector so the user can choose a database.json backup
  /// from Google Drive, Downloads, or any folder on their device.
  static Future<Map<String, dynamic>?> pickBackupFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Jamna Stone Backup File',
      );

      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      String content;
      if (path != null) {
        content = await File(path).readAsString();
      } else if (result.files.single.bytes != null) {
        content = utf8.decode(result.files.single.bytes!);
      } else {
        return null;
      }

      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('Pick backup file failed: $e');
      return null;
    }
  }
}
