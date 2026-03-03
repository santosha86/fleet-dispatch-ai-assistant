import 'dart:math';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/table_data.dart';

class DataTableView extends StatefulWidget {
  final TableData tableData;
  final Function(int page)? onPageSelect;
  final bool isLoadingPage;

  const DataTableView({
    super.key,
    required this.tableData,
    this.onPageSelect,
    this.isLoadingPage = false,
  });

  @override
  State<DataTableView> createState() => _DataTableViewState();
}

class _DataTableViewState extends State<DataTableView> {
  bool _showAll = false;
  final ScrollController _horizontalScrollController = ScrollController();
  late List<double> _columnWidths;

  @override
  void initState() {
    super.initState();
    _columnWidths = _calculateColumnWidths();
  }

  @override
  void didUpdateWidget(DataTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tableData != widget.tableData) {
      _columnWidths = _calculateColumnWidths();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  /// Calculate column widths based on header + sample data content
  List<double> _calculateColumnWidths() {
    const minWidth = 90.0;
    const maxWidth = 200.0;
    const charWidth = 7.5;
    const padding = 24.0;

    final columns = widget.tableData.columns;
    final rows = widget.tableData.rows;

    return List.generate(columns.length, (colIndex) {
      // Start with header width
      double maxContentWidth = columns[colIndex].length * charWidth;

      // Sample first 20 rows for max content width
      final sampleSize = min(20, rows.length);
      for (int i = 0; i < sampleSize; i++) {
        if (colIndex < rows[i].length) {
          final cellText = rows[i][colIndex]?.toString() ?? '';
          final cellWidth = min(cellText.length, 25) * charWidth;
          if (cellWidth > maxContentWidth) maxContentWidth = cellWidth;
        }
      }

      return (maxContentWidth + padding).clamp(minWidth, maxWidth);
    });
  }

  double get _totalTableWidth =>
      _columnWidths.fold(0.0, (sum, w) => sum + w);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxRows = AppConstants.maxVisibleTableRows;
    final totalRows = widget.tableData.rowCount;

    // Determine visible rows
    final visibleRows = _showAll
        ? widget.tableData.rows
        : widget.tableData.rows.take(maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scrollable table with fixed header
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 6,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _totalTableWidth,
                child: Column(
                  children: [
                    // Fixed header row
                    _buildHeaderRow(),
                    // Divider
                    Container(height: 1, color: AppColors.indigo500.withValues(alpha: 0.2)),
                    // Body rows
                    if (_showAll && visibleRows.length > maxRows)
                      // Scrollable body with fixed height when showing all
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          itemCount: visibleRows.length,
                          itemBuilder: (ctx, i) => _buildDataRow(visibleRows[i], i),
                        ),
                      )
                    else
                      // Non-scrollable body for small row counts
                      Column(
                        children: List.generate(
                          visibleRows.length,
                          (i) => _buildDataRow(visibleRows[i], i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Footer: row count + show more/less + pagination
        _buildFooter(l10n, maxRows, totalRows, visibleRows.length),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l10n, int maxRows, int totalRows, int visibleCount) {
    final hasPagination = widget.tableData.totalPages != null &&
        widget.tableData.totalPages! > 1;
    final serverTotal = widget.tableData.totalRowCount ?? totalRows;
    final showLocalToggle = totalRows > maxRows && !hasPagination;

    if (!showLocalToggle && !hasPagination) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.indigo500.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          // Local show all / show less toggle (only for non-paginated data)
          if (showLocalToggle)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l10n.showingRows(
                      _showAll ? totalRows : visibleCount,
                      serverTotal,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  icon: Icon(
                    _showAll ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _showAll ? 'Show less' : 'Show all',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

          // Page number navigation
          if (hasPagination) _buildPageNav(serverTotal),
        ],
      ),
    );
  }

  Widget _buildPageNav(int serverTotal) {
    final currentPage = widget.tableData.page ?? 1;
    final totalPages = widget.tableData.totalPages ?? 1;

    return Column(
      children: [
        // "Page X of Y (Z total rows)" label
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Page $currentPage of $totalPages ($serverTotal rows)',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        // Page buttons row
        if (widget.isLoadingPage)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildPageButtons(currentPage, totalPages),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildPageButtons(int currentPage, int totalPages) {
    final pages = _getVisiblePages(currentPage, totalPages);
    final buttons = <Widget>[];

    // Previous button
    buttons.add(_pageArrow(
      icon: Icons.chevron_left,
      enabled: currentPage > 1,
      onTap: () => widget.onPageSelect?.call(currentPage - 1),
    ));

    int? lastPage;
    for (final p in pages) {
      // Add ellipsis if there's a gap
      if (lastPage != null && p > lastPage + 1) {
        buttons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ));
      }
      buttons.add(_pageButton(p, p == currentPage));
      lastPage = p;
    }

    // Next button
    buttons.add(_pageArrow(
      icon: Icons.chevron_right,
      enabled: currentPage < totalPages,
      onTap: () => widget.onPageSelect?.call(currentPage + 1),
    ));

    return buttons;
  }

  /// Compute which page numbers to show: always show first, last,
  /// and a window around the current page.
  List<int> _getVisiblePages(int current, int total) {
    final pages = <int>{};
    pages.add(1);
    pages.add(total);
    for (int i = current - 2; i <= current + 2; i++) {
      if (i >= 1 && i <= total) pages.add(i);
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  Widget _pageButton(int page, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: isActive ? null : () => widget.onPageSelect?.call(page),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minWidth: 28),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.indigo500 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? null
                : Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : AppColors.indigo500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppColors.indigo500
              : AppColors.indigo500.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: AppColors.indigo500.withValues(alpha: 0.1),
      child: Row(
        children: List.generate(widget.tableData.columns.length, (i) {
          return Container(
            width: _columnWidths[i],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              widget.tableData.columns[i],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDataRow(List<dynamic> row, int rowIndex) {
    return Container(
      color: rowIndex.isEven
          ? Colors.transparent
          : AppColors.indigo500.withValues(alpha: 0.03),
      child: Row(
        children: List.generate(widget.tableData.columns.length, (colIndex) {
          final cellValue = colIndex < row.length
              ? row[colIndex]?.toString() ?? ''
              : '';
          return Container(
            width: _columnWidths[colIndex],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              cellValue,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ),
    );
  }
}
