import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/slab_models.dart';

class StorageService {
  static const String _draftKey = 'current_draft';
  static const String _draftUnitKey = 'current_draft_unit';
  static const String _historyKey = 'slab_books_history';
  
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

  static Future<void> saveBook(SlabBook book) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    
    // Check if updating existing or adding new
    final existingIndex = history.indexWhere((b) => b.id == book.id);
    if (existingIndex >= 0) {
      history[existingIndex] = book;
    } else {
      history.add(book);
    }
    
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, jsonString);
  }

  static Future<List<SlabBook>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historyKey);
    if (jsonString != null) {
      try {
        final List decoded = jsonDecode(jsonString);
        return decoded.map((e) => SlabBook.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }
  
  static Future<void> deleteBook(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.removeWhere((b) => b.id == id);
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, jsonString);
  }
}
