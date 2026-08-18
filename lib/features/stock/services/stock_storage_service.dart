import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/stock_models.dart';
import '../../slabs/services/backup_service.dart';

class StockStorageService {
  static const String _stockEntriesKey = 'stock_entries_data';
  static const String _blockNamesKey = 'block_names_data';
  static const String _blockTypesKey = 'block_types_data';

  // --- Block Types ---

  static Future<List<String>> loadBlockTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_blockTypesKey);
    
    if (jsonString != null) {
      try {
        final List decoded = jsonDecode(jsonString);
        return decoded.cast<String>();
      } catch (e) {
        return ['Marble', 'Granite'];
      }
    }
    return ['Marble', 'Granite'];
  }

  static Future<void> saveBlockType(String type) async {
    final types = await loadBlockTypes();
    
    if (!types.contains(type)) {
      types.add(type);
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(types);
      await prefs.setString(_blockTypesKey, jsonString);
    }
  }

  // --- Block Names ---

  static Future<List<String>> loadBlockNames() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_blockNamesKey);
    
    if (jsonString != null) {
      try {
        final List decoded = jsonDecode(jsonString);
        return decoded.cast<String>();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static Future<void> saveBlockName(String name) async {
    final names = await loadBlockNames();
    
    if (!names.contains(name)) {
      names.add(name);
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(names);
      await prefs.setString(_blockNamesKey, jsonString);
      BackupService.silentDatabaseSync();
    }
  }

  // --- Stock Entries ---

  static Future<List<StockEntry>> loadStockEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_stockEntriesKey);
    
    if (jsonString != null) {
      try {
        final List decoded = jsonDecode(jsonString);
        return decoded.map((e) => StockEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static Future<void> saveStockEntry(StockEntry entry) async {
    final entries = await loadStockEntries();
    
    entry.isSynced = false;
    
    final existingIndex = entries.indexWhere((e) => e.id == entry.id);
    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }
    
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_stockEntriesKey, jsonString);
    BackupService.silentDatabaseSync();
  }

  static Future<void> deleteStockEntry(String id) async {
    final entries = await loadStockEntries();
    entries.removeWhere((e) => e.id == id);
    
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_stockEntriesKey, jsonString);
    BackupService.silentDatabaseSync();
  }

  static Future<StockEntry?> getStockEntry(String id) async {
    final entries = await loadStockEntries();
    try {
      return entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<List<StockEntry>> getAvailableStockEntries() async {
    final entries = await loadStockEntries();
    return entries.where((e) => !e.isSold).toList();
  }

  static Future<void> updateStockSoldStatus(String stockId, double totalBookArea) async {
    final entries = await loadStockEntries();
    final index = entries.indexWhere((e) => e.id == stockId);
    if (index >= 0) {
      entries[index].isSold = totalBookArea >= entries[index].estimatedArea;
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_stockEntriesKey, jsonString);
      BackupService.silentDatabaseSync();
    }
  }
  static Future<void> forceMarkAsSold(String stockId, bool isSold) async {
    final entries = await loadStockEntries();
    final index = entries.indexWhere((e) => e.id == stockId);
    if (index >= 0) {
      entries[index].isSold = isSold;
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_stockEntriesKey, jsonString);
      BackupService.silentDatabaseSync();
    }
  }
}
