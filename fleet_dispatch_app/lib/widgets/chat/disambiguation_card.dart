import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';
import '../../models/disambiguation_option.dart';

class DisambiguationCard extends StatelessWidget {
  final List<DisambiguationOption> options;
  final Function(String) onSelect;

  const DisambiguationCard({
    super.key,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectOption,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return OutlinedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onSelect(option.value);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.indigo500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(option.displayText),
            );
          }).toList(),
        ),
      ],
    );
  }
}
