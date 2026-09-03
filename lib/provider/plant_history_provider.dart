import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/data_model/plant_history_model.dart';
import '../model/data_model/plant_model.dart';

class PlantHistoryProvider extends ChangeNotifier {
  List<PlantHistory> _history = [];
  static const String _storageKey = 'plant_scan_history';

  List<PlantHistory> get history => _history;

  PlantHistoryProvider() {
    loadHistory();
  }

  // Load history from SharedPreferences
  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_storageKey);

      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _history = decoded.map((json) => PlantHistory.fromJson(json)).toList();
        
        // Sort by most recent first
        _history.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  // Save history to SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          _history.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  // Add a scanned plant to history. Low-confidence / unconfirmed results
  // must not appear as successful identifications.
  Future<void> addToHistory(Plant plant) async {
    if (plant.identityConfirmation == IdentityStatus.unconfirmed) {
      return;
    }
    final historyItem = PlantHistory.fromPlant(plant);
    
    // Add to beginning of list (most recent first)
    _history.insert(0, historyItem);
    
    // Optional: Limit history to last 100 items
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    
    await _saveHistory();
    notifyListeners();
  }

  // Delete a history item
  Future<void> deleteHistoryItem(String id) async {
    _history.removeWhere((item) => item.id == id);
    await _saveHistory();
    notifyListeners();
  }

  // Clear all history
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  // Get history grouped by date
  Map<String, List<PlantHistory>> getGroupedHistory() {
    final Map<String, List<PlantHistory>> grouped = {};
    
    for (var item in _history) {
      final dateKey = _formatDateKey(item.scannedAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(item);
    }
    
    return grouped;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(itemDate).inDays < 7) {
      return '${_getDayName(date.weekday)}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  // Search history
  List<PlantHistory> searchHistory(String query) {
    if (query.isEmpty) return _history;
    
    final lowerQuery = query.toLowerCase();
    return _history.where((item) {
      return item.plantName.toLowerCase().contains(lowerQuery) ||
          item.scientificName.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
