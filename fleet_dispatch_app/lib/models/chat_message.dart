import 'table_data.dart';
import 'visualization_config.dart';
import 'disambiguation_option.dart';
import 'clarification_option.dart';
import 'query_response.dart';

enum MessageRole { user, assistant }

class MessageMetadata {
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

  MessageMetadata({
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

  factory MessageMetadata.fromQueryResponse(QueryResponse response) {
    return MessageMetadata(
      responseTime: response.responseTime,
      sources: response.sources,
      tableData: response.tableData,
      sqlQuery: response.sqlQuery,
      needsDisambiguation: response.needsDisambiguation,
      disambiguationOptions: response.disambiguationOptions,
      needsClarification: response.needsClarification,
      clarificationMessage: response.clarificationMessage,
      clarificationOptions: response.clarificationOptions,
      visualization: response.visualization,
    );
  }

  /// Returns a copy with the tableData replaced
  MessageMetadata copyWithTableData(TableData newTableData) {
    return MessageMetadata(
      responseTime: responseTime,
      sources: sources,
      tableData: newTableData,
      sqlQuery: sqlQuery,
      needsDisambiguation: needsDisambiguation,
      disambiguationOptions: disambiguationOptions,
      needsClarification: needsClarification,
      clarificationMessage: clarificationMessage,
      clarificationOptions: clarificationOptions,
      visualization: visualization,
    );
  }
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final String? originalQuery;
  final MessageMetadata? metadata;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.originalQuery,
    this.metadata,
  });

  /// Returns a copy with a new metadata
  ChatMessage copyWithMetadata(MessageMetadata newMetadata) {
    return ChatMessage(
      id: id,
      role: role,
      content: content,
      timestamp: timestamp,
      originalQuery: originalQuery,
      metadata: newMetadata,
    );
  }
}
