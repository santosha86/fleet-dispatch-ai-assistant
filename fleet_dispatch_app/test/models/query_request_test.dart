import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/query_request.dart';

void main() {
  group('QueryRequest', () {
    test('toJson includes only query when no optional fields', () {
      final request = QueryRequest(query: 'How many waybills?');

      final json = request.toJson();

      expect(json['query'], 'How many waybills?');
      expect(json.containsKey('session_id'), false);
      expect(json.containsKey('route'), false);
    });

    test('toJson includes session_id when provided', () {
      final request = QueryRequest(
        query: 'test query',
        sessionId: 'abc-123-def',
      );

      final json = request.toJson();

      expect(json['query'], 'test query');
      expect(json['session_id'], 'abc-123-def');
      expect(json.containsKey('route'), false);
    });

    test('toJson includes route when provided', () {
      final request = QueryRequest(
        query: 'test query',
        route: 'sql',
      );

      final json = request.toJson();

      expect(json['query'], 'test query');
      expect(json['route'], 'sql');
      expect(json.containsKey('session_id'), false);
    });

    test('toJson includes all fields when provided', () {
      final request = QueryRequest(
        query: 'Which fuel type?',
        sessionId: 'session-456',
        route: 'csv',
      );

      final json = request.toJson();

      expect(json['query'], 'Which fuel type?');
      expect(json['session_id'], 'session-456');
      expect(json['route'], 'csv');
      expect(json.length, 3);
    });

    test('constructor stores values correctly', () {
      final request = QueryRequest(
        query: 'test',
        sessionId: 'sid',
        route: 'pdf',
      );

      expect(request.query, 'test');
      expect(request.sessionId, 'sid');
      expect(request.route, 'pdf');
    });
  });
}
