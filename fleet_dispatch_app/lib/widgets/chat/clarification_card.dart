import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';
import '../../models/clarification_option.dart';

class ClarificationCard extends StatelessWidget {
  final String message;
  final List<ClarificationOption> options;
  final String originalQuery;
  final Function(String, String) onSelect;

  const ClarificationCard({
    super.key,
    required this.message,
    required this.options,
    required this.originalQuery,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.isNotEmpty ? message : l10n.selectDataSource,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                onSelect(option.route, originalQuery);
              },
              icon: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back
                    : Icons.arrow_forward,
                size: 16,
              ),
              label: Text(option.label),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.indigo500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
          );
        }),
      ],
    );
  }
}
