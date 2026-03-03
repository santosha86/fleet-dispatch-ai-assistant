import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/table_data.dart';

class CsvExporter {
  /// Export TableData as CSV file and trigger share/save
  static Future<void> exportTableData(
    TableData tableData, {
    String? filename,
  }) async {
    final csvRows = <String>[];

    // Header row
    csvRows.add(tableData.columns.map((col) => '"$col"').join(','));

    // Data rows
    for (final row in tableData.rows) {
      csvRows.add(row.map((cell) {
        final value = cell?.toString() ?? '';
        return '"${value.replaceAll('"', '""')}"';
      }).join(','));
    }

    // UTF-8 BOM for Excel compatibility with Arabic
    final csvContent = '\uFEFF${csvRows.join('\n')}';

    // Save to temp directory
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${filename ?? 'query_results_${DateTime.now().millisecondsSinceEpoch}'}.csv',
    );
    await file.writeAsString(csvContent);

    // Share
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Query Results',
    );
  }
}
