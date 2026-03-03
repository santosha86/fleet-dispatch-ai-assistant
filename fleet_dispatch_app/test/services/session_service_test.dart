import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/services/session_service.dart';
import '../helpers/mock_api_client.dart';

void main() {
  group('SessionService', () {
    test('clearSession sends correct session_id to API', () async {
      String? capturedPath;
      dynamic capturedData;

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          capturedPath = path;
          capturedData = data;
          return {'status': 'ok'};
        },
      );
      final service = SessionService(mockClient);

      await service.clearSession('session-abc-123');

      expect(capturedPath, '/api/session/clear');
      expect(capturedData, {'session_id': 'session-abc-123'});
    });

    test('clearSession handles different session IDs', () async {
      dynamic capturedData;

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          capturedData = data;
          return {'status': 'ok'};
        },
      );
      final service = SessionService(mockClient);

      await service.clearSession('test-session-xyz');

      expect(capturedData['session_id'], 'test-session-xyz');
    });

    test('clearSession propagates API errors', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          throw Exception('Server error');
        },
      );
      final service = SessionService(mockClient);

      expect(
        () => service.clearSession('session-123'),
        throwsException,
      );
    });
  });
}
