import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/disambiguation_option.dart';

void main() {
  group('DisambiguationOption', () {
    test('fromJson parses Map with value and display', () {
      final json = {
        'value': 'Waybill Status',
        'display': 'Waybill Status',
        'description': 'Current status of the waybill',
      };

      final option = DisambiguationOption.fromJson(json);

      expect(option.value, 'Waybill Status');
      expect(option.label, 'Waybill Status');
      expect(option.displayText, 'Waybill Status');
    });

    test('fromJson parses plain String', () {
      final option = DisambiguationOption.fromJson('Requested Quantity');

      expect(option.value, 'Requested Quantity');
      expect(option.label, null);
      expect(option.displayText, 'Requested Quantity');
    });

    test('fromJson handles Map with null display', () {
      final json = <String, dynamic>{
        'value': 'test_value',
        'display': null,
      };

      final option = DisambiguationOption.fromJson(json);

      expect(option.value, 'test_value');
      expect(option.label, null);
      expect(option.displayText, 'test_value');
    });

    test('fromJson handles non-String non-Map input', () {
      final option = DisambiguationOption.fromJson(42);

      expect(option.value, '42');
    });

    test('fromJson handles empty Map', () {
      final json = <String, dynamic>{};
      final option = DisambiguationOption.fromJson(json);

      expect(option.value, '');
      expect(option.label, null);
      expect(option.displayText, '');
    });

    test('displayText prefers label over value', () {
      final option = DisambiguationOption(
        value: 'raw_value',
        label: 'Display Label',
      );

      expect(option.displayText, 'Display Label');
    });

    test('displayText falls back to value when label is null', () {
      final option = DisambiguationOption(value: 'fallback_value');

      expect(option.displayText, 'fallback_value');
    });
  });
}
