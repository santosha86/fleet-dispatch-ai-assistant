import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/table_data.dart';

void main() {
  group('TableData', () {
    test('fromJson parses correctly', () {
      final json = {
        'columns': ['Vendor Name', 'total_requests'],
        'rows': [
          ['ZAID M. AL-GHANNAM', 1451],
          ['Hashr Ghazi Al-Sehly', 1087],
        ],
      };

      final tableData = TableData.fromJson(json);

      expect(tableData.columns, ['Vendor Name', 'total_requests']);
      expect(tableData.rows.length, 2);
      expect(tableData.rows[0][0], 'ZAID M. AL-GHANNAM');
      expect(tableData.rows[0][1], 1451);
    });

    test('fromJson handles null columns', () {
      final json = <String, dynamic>{'columns': null, 'rows': null};
      final tableData = TableData.fromJson(json);

      expect(tableData.columns, isEmpty);
      expect(tableData.rows, isEmpty);
    });

    test('fromJson handles missing keys', () {
      final json = <String, dynamic>{};
      final tableData = TableData.fromJson(json);

      expect(tableData.columns, isEmpty);
      expect(tableData.rows, isEmpty);
    });

    test('toJson produces correct output', () {
      final tableData = TableData(
        columns: ['col1', 'col2'],
        rows: [
          [1, 'a'],
          [2, 'b'],
        ],
      );

      final json = tableData.toJson();
      expect(json['columns'], ['col1', 'col2']);
      expect(json['rows'], [
        [1, 'a'],
        [2, 'b'],
      ]);
    });

    test('rowCount returns correct count', () {
      final tableData = TableData(
        columns: ['a'],
        rows: [
          [1],
          [2],
          [3],
        ],
      );
      expect(tableData.rowCount, 3);
    });

    test('hasData returns true when rows exist', () {
      final tableData = TableData(columns: ['a'], rows: [
        [1]
      ]);
      expect(tableData.hasData, true);
    });

    test('hasData returns false when no rows', () {
      final tableData = TableData(columns: ['a'], rows: []);
      expect(tableData.hasData, false);
    });

    test('fromJson handles mixed type rows', () {
      final json = {
        'columns': ['Name', 'Count', 'Active'],
        'rows': [
          ['Test', 42, true],
          ['Other', null, false],
        ],
      };

      final tableData = TableData.fromJson(json);
      expect(tableData.rows[0][1], 42);
      expect(tableData.rows[1][1], null);
    });
  });
}
