import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';
import '../../core/utils/csv_exporter.dart';
import '../../models/table_data.dart';

class MessageMetadataBar extends StatelessWidget {
  final String responseTime;
  final List<String> sources;
  final TableData? tableData;

  const MessageMetadataBar({
    super.key,
    required this.responseTime,
    required this.sources,
    this.tableData,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        // Response time
        Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          responseTime,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(width: 12),

        // Sources
        ...sources.take(2).map((source) {
          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.indigo500.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              source,
              style: const TextStyle(fontSize: 10, color: AppColors.indigo500),
            ),
          );
        }),

        const Spacer(),

        // CSV export button — disabled for corporate security (no data download on device)
        // To re-enable, uncomment the block below:
        // if (tableData != null && tableData!.hasData)
        //   InkWell(
        //     onTap: () => CsvExporter.exportTableData(tableData!),
        //     borderRadius: BorderRadius.circular(4),
        //     child: Padding(
        //       padding: const EdgeInsets.all(4),
        //       child: Row(
        //         mainAxisSize: MainAxisSize.min,
        //         children: [
        //           const Icon(
        //             Icons.download,
        //             size: 14,
        //             color: AppColors.indigo500,
        //           ),
        //           const SizedBox(width: 2),
        //           Text(
        //             l10n.downloadCsv,
        //             style: const TextStyle(
        //               fontSize: 11,
        //               color: AppColors.indigo500,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
      ],
    );
  }
}
