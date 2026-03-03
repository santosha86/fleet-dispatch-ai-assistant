import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/category.dart';

void main() {
  group('Category', () {
    test('fromJson parses complete backend response', () {
      final json = {
        'id': 'ops',
        'label': 'Operations',
        'icon': 'Truck',
        'queries': [
          'How many waybills are Delivered / Expired / Cancelled?',
          'Which fuel type has the highest total requested quantity?',
        ],
      };

      final category = Category.fromJson(json);

      expect(category.id, 'ops');
      expect(category.label, 'Operations');
      expect(category.icon, 'Truck');
      expect(category.queries.length, 2);
      expect(category.queries[0], contains('waybills'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final category = Category.fromJson(json);

      expect(category.id, '');
      expect(category.label, '');
      expect(category.icon, 'HelpCircle');
      expect(category.queries, isEmpty);
    });

    test('fromJson handles null queries', () {
      final json = <String, dynamic>{
        'id': 'test',
        'label': 'Test',
        'icon': 'Settings',
        'queries': null,
      };

      final category = Category.fromJson(json);

      expect(category.queries, isEmpty);
    });

    test('fromJson parses all 4 backend categories', () {
      final categoriesJson = [
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

      final categories = categoriesJson
          .map((j) => Category.fromJson(j))
          .toList();

      expect(categories.length, 4);
      expect(categories[0].icon, 'Truck');
      expect(categories[3].icon, 'TrendingUp');
    });
  });
}
