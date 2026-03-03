import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/category.dart';

class CategoryChipBar extends StatefulWidget {
  final AsyncValue<List<Category>> categories;
  final Function(String) onQueryTap;

  const CategoryChipBar({
    super.key,
    required this.categories,
    required this.onQueryTap,
  });

  @override
  State<CategoryChipBar> createState() => _CategoryChipBarState();
}

class _CategoryChipBarState extends State<CategoryChipBar> {
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    return widget.categories.when(
      data: (cats) => _buildBar(context, cats),
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildBar(BuildContext context, List<Category> cats) {
    if (cats.isEmpty) return const SizedBox.shrink();

    final selected = _expandedCategory != null
        ? cats.where((c) => c.id == _expandedCategory).firstOrNull
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Horizontal scrollable category chips
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.indigo500.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: cats.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = cats[index];
              final isSelected = cat.id == _expandedCategory;
              final iconData =
                  AppConstants.categoryIcons[cat.icon] ?? Icons.help_outline;

              return ActionChip(
                avatar: Icon(iconData, size: 14),
                label: Text(cat.label, style: const TextStyle(fontSize: 11)),
                backgroundColor: isSelected
                    ? AppColors.indigo600.withValues(alpha: 0.3)
                    : null,
                side: isSelected
                    ? const BorderSide(color: AppColors.indigo500)
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                labelPadding: const EdgeInsets.only(left: 2, right: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _expandedCategory =
                        isSelected ? null : cat.id;
                  });
                },
              );
            },
          ),
        ),

        // Expanded query list
        if (selected != null)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.indigo500.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shrinkWrap: true,
              itemCount: selected.queries.length,
              itemBuilder: (context, index) {
                final query = selected.queries[index];
                return InkWell(
                  onTap: () {
                    setState(() => _expandedCategory = null);
                    widget.onQueryTap(query);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            query,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_ios
                              : Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.indigo500,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
