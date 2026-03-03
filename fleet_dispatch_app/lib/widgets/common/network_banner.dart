import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';

class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.warning,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.errorConnect,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
