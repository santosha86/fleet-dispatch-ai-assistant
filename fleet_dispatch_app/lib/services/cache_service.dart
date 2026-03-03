import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Caches recent query/response pairs for offline access.
/// Stores up to [maxEntries] items in a Hive box.
class CacheService {
  static const String _boxName = 'chat_cache';
  static const int maxEntries = 50;

  Box<String>? _box;
  bool _initializing = false;

  /// Lazily open the Hive box on first use.
  Future<Box<String>?> _getBox() async {
    if (_box != null && _box!.isOpen) return _box;
    if (_initializing) return null; // Prevent re-entrant init
    _initializing = true;
    try {
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      debugPrint('CacheService: Failed to open Hive box: $e');
    }
    _initializing = false;
    return _box;
  }

  /// Cache a query-response pair.
  /// Key is the lowercase trimmed query text.
  Future<void> cacheResponse({
    required String query,
    required Map<String, dynamic> responseJson,
  }) async {
    final box = await _getBox();
    if (box == null) return;

    final key = _normalizeKey(query);
    final value = jsonEncode({
      'query': query,
      'response': responseJson,
      'cachedAt': DateTime.now().toIso8601String(),
    });

    await box.put(key, value);

    // Evict oldest entries if over limit
    if (box.length > maxEntries) {
      final keysToRemove = box.keys.take(box.length - maxEntries).toList();
      for (final k in keysToRemove) {
        await box.delete(k);
      }
    }
  }

  /// Retrieve a cached response for the given query.
  /// Returns null if not found.
  Map<String, dynamic>? getCachedResponse(String query) {
    final box = _box;
    if (box == null || !box.isOpen) return null;

    final key = _normalizeKey(query);
    final value = box.get(key);
    if (value == null) return null;

    final decoded = jsonDecode(value) as Map<String, dynamic>;
    return decoded['response'] as Map<String, dynamic>?;
  }

  /// Check if a query has a cached response.
  bool hasCachedResponse(String query) {
    final box = _box;
    if (box == null || !box.isOpen) return false;
    return box.containsKey(_normalizeKey(query));
  }

  /// Get all cached queries (for display purposes).
  List<String> getCachedQueries() {
    final box = _box;
    if (box == null || !box.isOpen) return [];

    return box.values.map((value) {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return decoded['query'] as String? ?? '';
    }).where((q) => q.isNotEmpty).toList();
  }

  /// Clear all cached data.
  Future<void> clearCache() async {
    await _box?.clear();
  }

  String _normalizeKey(String query) {
    return query.trim().toLowerCase();
  }
}
