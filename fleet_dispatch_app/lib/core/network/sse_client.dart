import 'dart:async';
import 'dart:convert';

import '../../models/query_request.dart';
import '../../models/sse_event.dart';
import '../../models/table_data.dart';
import '../../models/visualization_config.dart';
import '../../models/disambiguation_option.dart';
import '../../models/clarification_option.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class SSEClient {
  final ApiClient _apiClient;
  StreamSubscription<List<int>>? _subscription;
  StreamController<SSEEvent>? _controller;

  SSEClient(this._apiClient);

  /// Connect to SSE endpoint and emit parsed events
  Stream<SSEEvent> connect({
    required String query,
    required String sessionId,
    String? route,
    int? maxRows,
    int? pageSize,
  }) async* {
    final controller = StreamController<SSEEvent>();
    _controller = controller;

    try {
      final response = await _apiClient.postStream(
        ApiEndpoints.queryStream,
        data: QueryRequest(
          query: query,
          sessionId: sessionId,
          route: route,
          maxRows: maxRows,
          pageSize: pageSize,
        ).toJson(),
      );

      final stream = response.data!.stream;
      final buffer = StringBuffer();

      _subscription = stream.listen(
        (chunk) {
          final decoded = utf8.decode(chunk, allowMalformed: true);
          buffer.write(decoded);
          final content = buffer.toString();

          // Parse SSE format: "data: {json}\n\n"
          final lines = content.split('\n');
          buffer.clear();

          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];

            if (line.startsWith('data: ')) {
              try {
                final jsonStr = line.substring(6);
                final data = json.decode(jsonStr) as Map<String, dynamic>;
                final event = _parseEvent(data);
                controller.add(event);
              } catch (_) {
                // Incomplete JSON chunk, buffer for next iteration
                buffer.write(line);
                if (i < lines.length - 1) buffer.write('\n');
              }
            } else if (line.isNotEmpty) {
              buffer.write(line);
              if (i < lines.length - 1) buffer.write('\n');
            }
          }
        },
        onError: (error) {
          controller.add(SSEErrorEvent(message: error.toString()));
          _cleanup(controller);
        },
        onDone: () {
          _cleanup(controller);
        },
      );
    } catch (e) {
      controller.add(SSEErrorEvent(message: e.toString()));
      _cleanup(controller);
    }

    yield* controller.stream;
  }

  SSEEvent _parseEvent(Map<String, dynamic> data) {
    if (data['done'] == true) {
      return SSEDoneEvent(
        content: data['content'] as String? ?? '',
        responseTime: data['response_time'] as String? ?? '0s',
        sources: (data['sources'] as List?)?.cast<String>() ?? ['System'],
        tableData: data['table_data'] != null
            ? TableData.fromJson(data['table_data'] as Map<String, dynamic>)
            : null,
        sqlQuery: data['sql_query'] as String?,
        needsDisambiguation: data['needs_disambiguation'] as bool? ?? false,
        disambiguationOptions: (data['disambiguation_options'] as List?)
            ?.map((e) => DisambiguationOption.fromJson(e))
            .toList(),
        needsClarification: data['needs_clarification'] as bool? ?? false,
        clarificationMessage: data['clarification_message'] as String?,
        clarificationOptions: (data['clarification_options'] as List?)
            ?.map((e) =>
                ClarificationOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        visualization: data['visualization'] != null
            ? VisualizationConfig.fromJson(
                data['visualization'] as Map<String, dynamic>)
            : null,
      );
    } else if (data['phase'] != null) {
      return SSEPhaseEvent(
        phase: data['phase'] as String,
        content: data['content'] as String?,
      );
    }
    return SSEErrorEvent(message: 'Unknown event format');
  }

  void _cleanup(StreamController<SSEEvent> controller) {
    if (!controller.isClosed) {
      controller.close();
    }
    _controller = null;
  }

  /// Cancel active stream
  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    // Close the controller so the await-for loop in the provider terminates
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _controller = null;
  }
}
