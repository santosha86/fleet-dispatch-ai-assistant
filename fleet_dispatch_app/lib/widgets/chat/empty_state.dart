import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/category.dart';

class EmptyState extends StatelessWidget {
  final AsyncValue<List<Category>> categories;
  final String? selectedCategory;
  final Function(String) onCategoryTap;
  final Function(String) onQueryTap;

  const EmptyState({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryTap,
    required this.onQueryTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Company logo
          Image.asset(
            'assets/images/fleet_logo.png',
            height: 100,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.howCanIHelp,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.askAbout,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Categories
          categories.when(
            data: (cats) => _buildCategories(context, cats),
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, List<Category> cats) {
    // Find selected category's queries
    final selected = selectedCategory != null
        ? cats.where((c) => c.id == selectedCategory).firstOrNull
        : null;

    return Column(
      children: [
        // Category chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.map((cat) {
            final isSelected = cat.id == selectedCategory;
            final iconData =
                AppConstants.categoryIcons[cat.icon] ?? Icons.help_outline;

            return ActionChip(
              avatar: Icon(iconData, size: 18),
              label: Text(cat.label),
              backgroundColor: isSelected
                  ? AppColors.indigo600.withValues(alpha: 0.3)
                  : null,
              side: isSelected
                  ? const BorderSide(color: AppColors.indigo500)
                  : null,
              onPressed: () => onCategoryTap(
                isSelected ? '' : cat.id,
              ),
            );
          }).toList(),
        ),

        // Selected category queries
        if (selected != null) ...[
          const SizedBox(height: 16),
          ...selected.queries.map((query) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onQueryTap(query),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.indigo500.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          query,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_back_ios
                            : Icons.arrow_forward_ios,
                        size: 14,
                        color: AppColors.indigo500,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
