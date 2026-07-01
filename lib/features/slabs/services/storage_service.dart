import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/slab_models.dart';

class StorageService {
  static const String _draftKey = 'current_draft';
  static const String _draftUnitKey = 'current_draft_unit';
  static const String _historyKey = 'slab_books_history';
  static const String _fileName = 'jamna_history_v2.json';
  
  static Future<File> _getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> saveDraft(List<SlabEntry> slabs, String unit) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(slabs.map((e) => e.toJson()).toList());
    await prefs.setString(_draftKey, jsonString);
    await prefs.setString(_draftUnitKey, unit);
  }

  static Future<Map<String, dynamic>> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_draftKey);
    final unit = prefs.getString(_draftUnitKey) ?? 'Feet';
    
    if (jsonString != null) {
      try {
        final List decoded = jsonDecode(jsonString);
        final slabs = decoded.map((e) => SlabEntry.fromJson(e as Map<String, dynamic>)).toList();
        return {'slabs': slabs, 'unit': unit};
      } catch (e) {
        return {'slabs': <SlabEntry>[], 'unit': unit};
      }
    }
    return {'slabs': <SlabEntry>[], 'unit': unit};
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  static Future<void> _writeHistory(List<SlabBook> history) async {
    final file = await _getHistoryFile();
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    
    // Write to a temporary file first for atomic safety against crashes
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonString, flush: true);
    await tempFile.rename(file.path);
  }

  static Future<void> saveBook(SlabBook book) async {
    final history = await loadHistory();
    
    final existingIndex = history.indexWhere((b) => b.id == book.id);
    if (existingIndex >= 0) {
      history[existingIndex] = book;
    } else {
      history.add(book);
    }
    
    await _writeHistory(history);
  }

  static Future<List<SlabBook>> loadHistory() async {
    final file = await _getHistoryFile();
    
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final List decoded = jsonDecode(jsonString);
        return decoded.map((e) => SlabBook.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        return [];
      }
    } else {
      // Migration from SharedPreferences (Old versions)
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyKey);
      if (jsonString != null) {
        try {
          final List decoded = jsonDecode(jsonString);
          final history = decoded.map((e) => SlabBook.fromJson(e as Map<String, dynamic>)).toList();
          
          // Save to file and remove from SharedPreferences to complete migration
          await _writeHistory(history);
          await prefs.remove(_historyKey);
          
          return history;
        } catch (e) {
          return [];
        }
      }
    }
    
    return [];
  }
  
  static Future<void> deleteBook(String id) async {
    final history = await loadHistory();
    history.removeWhere((b) => b.id == id);
    await _writeHistory(history);
  }
}
