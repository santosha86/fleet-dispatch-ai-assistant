import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/services/category_service.dart';
import '../helpers/mock_api_client.dart';

void main() {
  group('CategoryService', () {
    test('getCategories returns parsed Category list', () async {
      final mockClient = MockApiClient(
        onGet: (path) {
          if (path == '/api/categories') {
            return [
              {
                'id': 'ops',
                'label': 'Operations',
                'icon': 'Truck',
                'queries': ['q1', 'q2'],
              },
              {
                'id': 'waybills',
                'label': 'Waybills',
                'icon': 'FileText',
                'queries': ['q3'],
              },
              {
                'id': 'contractors',
                'label': 'Contractors',
                'icon': 'Users',
                'queries': ['q4'],
              },
              {
                'id': 'Status Inquiry',
                'label': 'Status Inquiry',
                'icon': 'TrendingUp',
                'queries': ['q5', 'q6'],
              },
            ];
          }
          throw Exception('Unexpected path: $path');
        },
      );
      final service = CategoryService(mockClient);

      final categories = await service.getCategories();

      expect(categories.length, 4);
      expect(categories[0].id, 'ops');
      expect(categories[0].label, 'Operations');
      expect(categories[0].icon, 'Truck');
      expect(categories[0].queries.length, 2);
      expect(categories[3].id, 'Status Inquiry');
      expect(categories[3].icon, 'TrendingUp');
    });

    test('getCategories handles empty list', () async {
      final mockClient = MockApiClient(
        onGet: (path) => [],
      );
      final service = CategoryService(mockClient);

      final categories = await service.getCategories();

      expect(categories, isEmpty);
    });

    test('getCategoryQueries returns list of query strings', () async {
      final mockClient = MockApiClient(
        onGet: (path) {
          if (path == '/api/categories/ops/queries') {
            return [
              'How many waybills are Delivered?',
              'Which fuel type has the highest quantity?',
              'Show top 5 vendors by request count',
            ];
          }
          throw Exception('Unexpected path: $path');
        },
      );
      final service = CategoryService(mockClient);

      final queries = await service.getCategoryQueries('ops');

      expect(queries.length, 3);
      expect(queries[0], contains('waybills'));
      expect(queries[2], contains('vendors'));
    });

    test('getCategoryQueries handles empty list', () async {
      final mockClient = MockApiClient(
        onGet: (path) => [],
      );
      final service = CategoryService(mockClient);

      final queries = await service.getCategoryQueries('unknown');

      expect(queries, isEmpty);
    });
  });
}
