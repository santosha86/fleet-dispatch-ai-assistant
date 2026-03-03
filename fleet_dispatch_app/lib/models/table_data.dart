class TableData {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final int? totalRowCount; // Total rows before server-side truncation
  final bool truncated; // Whether server truncated the rows
  final String? resultId; // Pagination: ID for fetching more pages
  final int? page; // Pagination: current page number (1-based)
  final int? totalPages; // Pagination: total number of pages
  final int? pageSize; // Pagination: rows per page

  TableData({
    required this.columns,
    required this.rows,
    this.totalRowCount,
    this.truncated = false,
    this.resultId,
    this.page,
    this.totalPages,
    this.pageSize,
  });

  factory TableData.fromJson(Map<String, dynamic> json) {
    return TableData(
      columns: List<String>.from(json['columns'] ?? []),
      rows: (json['rows'] as List?)
              ?.map((row) => List<dynamic>.from(row as List))
              .toList() ??
          [],
      totalRowCount: json['total_row_count'] as int?,
      truncated: json['truncated'] as bool? ?? false,
      resultId: json['result_id'] as String?,
      page: json['page'] as int?,
      totalPages: json['total_pages'] as int?,
      pageSize: json['page_size'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'rows': rows,
        'total_row_count': totalRowCount,
        'truncated': truncated,
        'result_id': resultId,
        'page': page,
        'total_pages': totalPages,
        'page_size': pageSize,
      };

  int get rowCount => rows.length;
  bool get hasData => rows.isNotEmpty;

  /// Whether there are more pages available to load
  bool get hasMorePages =>
      resultId != null &&
      page != null &&
      totalPages != null &&
      page! < totalPages!;

  /// Returns a new TableData replacing current rows with [newPage] data.
  TableData replacePage(TableData newPage) {
    return TableData(
      columns: columns,
      rows: newPage.rows,
      totalRowCount: newPage.totalRowCount ?? totalRowCount,
      truncated: truncated,
      resultId: resultId,
      page: newPage.page,
      totalPages: newPage.totalPages ?? totalPages,
      pageSize: newPage.pageSize ?? pageSize,
    );
  }
}
