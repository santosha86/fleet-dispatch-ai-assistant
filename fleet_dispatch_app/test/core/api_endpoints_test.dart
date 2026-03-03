import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/core/network/api_endpoints.dart';

void main() {
  group('ApiEndpoints', () {
    test('healthCheck is root path', () {
      expect(ApiEndpoints.healthCheck, '/');
    });

    test('aiOverview path', () {
      expect(ApiEndpoints.aiOverview, '/api/ai-overview');
    });

    test('usageStats path', () {
      expect(ApiEndpoints.usageStats, '/api/usage-stats');
    });

    test('categories path', () {
      expect(ApiEndpoints.categories, '/api/categories');
    });

    test('categoryQueries builds dynamic path', () {
      expect(ApiEndpoints.categoryQueries('ops'), '/api/categories/ops/queries');
      expect(
        ApiEndpoints.categoryQueries('Status Inquiry'),
        '/api/categories/Status Inquiry/queries',
      );
    });

    test('query path', () {
      expect(ApiEndpoints.query, '/api/query');
    });

    test('queryStream path', () {
      expect(ApiEndpoints.queryStream, '/api/query/stream');
    });

    test('route path', () {
      expect(ApiEndpoints.route, '/api/route');
    });

    test('sessionClear path', () {
      expect(ApiEndpoints.sessionClear, '/api/session/clear');
    });
  });
}
