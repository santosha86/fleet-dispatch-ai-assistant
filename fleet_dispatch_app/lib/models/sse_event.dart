import 'table_data.dart';
import 'visualization_config.dart';
import 'disambiguation_option.dart';
import 'clarification_option.dart';

sealed class SSEEvent {}

class SSEPhaseEvent extends SSEEvent {
  final String phase;
  final String? content;

  SSEPhaseEvent({required this.phase, this.content});
}

class SSEDoneEvent extends SSEEvent {
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

  SSEDoneEvent({
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
}

class SSEErrorEvent extends SSEEvent {
  final String message;
  SSEErrorEvent({required this.message});
}
