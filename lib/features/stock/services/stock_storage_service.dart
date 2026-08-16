import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/stock_models.dart';

class StockStorageService {
  static const String _stockEntriesKey = 'stock_entries_data';
  static const String _blockNamesKey = 'block_names_data';

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
  }

  static Future<void> deleteStockEntry(String id) async {
    final entries = await loadStockEntries();
    entries.removeWhere((e) => e.id == id);
    
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_stockEntriesKey, jsonString);
  }
}
