import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/core/utils/session_manager.dart';

void main() {
  group('SessionManager', () {
    test('generateSessionId returns a non-empty string', () {
      final id = SessionManager.generateSessionId();
      expect(id, isNotEmpty);
    });

    test('generateSessionId returns UUID v4 format', () {
      final id = SessionManager.generateSessionId();

      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidRegex.hasMatch(id), true, reason: 'Should be valid UUID v4: $id');
    });

    test('generateSessionId returns unique values', () {
      final ids = List.generate(100, (_) => SessionManager.generateSessionId());
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, 100, reason: 'All 100 generated IDs should be unique');
    });
  });
}
