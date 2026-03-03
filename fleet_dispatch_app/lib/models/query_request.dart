class QueryRequest {
  final String query;
  final String? sessionId;
  final String? route;
  final int? maxRows;
  final int? pageSize;

  QueryRequest({
    required this.query,
    this.sessionId,
    this.route,
    this.maxRows,
    this.pageSize,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'query': query};
    if (sessionId != null) json['session_id'] = sessionId;
    if (route != null) json['route'] = route;
    if (maxRows != null) json['max_rows'] = maxRows;
    if (pageSize != null) json['page_size'] = pageSize;
    return json;
  }
}
