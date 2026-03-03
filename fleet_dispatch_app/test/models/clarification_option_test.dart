import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/clarification_option.dart';

void main() {
  group('ClarificationOption', () {
    test('fromJson parses value and label correctly', () {
      final json = {
        'value': 'sql',
        'label': 'Waybills Database',
        'description': 'Query the dispatch waybills database',
      };

      final option = ClarificationOption.fromJson(json);

      expect(option.route, 'sql');
      expect(option.label, 'Waybills Database');
    });

    test('fromJson maps backend value field to route property', () {
      final json = {
        'value': 'csv',
        'label': 'Dwell Time Data',
      };

      final option = ClarificationOption.fromJson(json);

      // Backend sends "value" which contains the route string
      expect(option.route, 'csv');
    });

    test('fromJson handles missing value field', () {
      final json = <String, dynamic>{
        'label': 'Some Label',
      };

      final option = ClarificationOption.fromJson(json);

      expect(option.route, '');
      expect(option.label, 'Some Label');
    });

    test('fromJson handles missing label field', () {
      final json = <String, dynamic>{
        'value': 'pdf',
      };

      final option = ClarificationOption.fromJson(json);

      expect(option.route, 'pdf');
      expect(option.label, '');
    });

    test('fromJson handles empty map', () {
      final json = <String, dynamic>{};

      final option = ClarificationOption.fromJson(json);

      expect(option.route, '');
      expect(option.label, '');
    });

    test('constructor creates option correctly', () {
      final option = ClarificationOption(route: 'math', label: 'Calculator');

      expect(option.route, 'math');
      expect(option.label, 'Calculator');
    });
  });
}
