import 'table_data.dart';
import 'visualization_config.dart';
import 'disambiguation_option.dart';
import 'clarification_option.dart';

class QueryResponse {
  final String content;
  final String responseTime;
  final List<String> sources;
  final TableData? tableData;
  final String? sqlQuery;
  final bool needsDisambiguation;
  final List<DisambiguationOption>? disambiguationOptions;
  final bool needsClarification;
  final String? clarificationMessage;
  final List<ClarificationOption>? clarificationOptions;
  final VisualizationConfig? visualization;

  QueryResponse({
    required this.content,
    required this.responseTime,
    required this.sources,
    this.tableData,
    this.sqlQuery,
    this.needsDisambiguation = false,
    this.disambiguationOptions,
    this.needsClarification = false,
    this.clarificationMessage,
    this.clarificationOptions,
    this.visualization,
  });

  factory QueryResponse.fromJson(Map<String, dynamic> json) {
    return QueryResponse(
      content: json['content'] as String? ?? '',
      responseTime: json['response_time'] as String? ?? '0s',
      sources: (json['sources'] as List?)?.cast<String>() ?? ['System'],
      tableData: json['table_data'] != null
          ? TableData.fromJson(json['table_data'] as Map<String, dynamic>)
          : null,
      sqlQuery: json['sql_query'] as String?,
      needsDisambiguation: json['needs_disambiguation'] as bool? ?? false,
      disambiguationOptions: (json['disambiguation_options'] as List?)
          ?.map((e) => DisambiguationOption.fromJson(e))
          .toList(),
      needsClarification: json['needs_clarification'] as bool? ?? false,
      clarificationMessage: json['clarification_message'] as String?,
      clarificationOptions: (json['clarification_options'] as List?)
          ?.map((e) => ClarificationOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      visualization: json['visualization'] != null
          ? VisualizationConfig.fromJson(
              json['visualization'] as Map<String, dynamic>)
          : null,
    );
  }
}
