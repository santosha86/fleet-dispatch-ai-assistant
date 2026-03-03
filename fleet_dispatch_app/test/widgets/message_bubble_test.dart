import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/chat_message.dart';
import 'package:fleet_dispatch_app/models/disambiguation_option.dart';
import 'package:fleet_dispatch_app/models/clarification_option.dart';
import 'package:fleet_dispatch_app/widgets/chat/message_bubble.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('renders user message text', (tester) async {
      final msg = ChatMessage(
        id: 'msg-1',
        role: MessageRole.user,
        content: 'How many waybills?',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('How many waybills?'), findsOneWidget);
    });

    testWidgets('user message is right-aligned', (tester) async {
      final msg = ChatMessage(
        id: 'msg-2',
        role: MessageRole.user,
        content: 'Test',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, AlignmentDirectional.centerEnd);
    });

    testWidgets('bot message is left-aligned', (tester) async {
      final msg = ChatMessage(
        id: 'msg-3',
        role: MessageRole.assistant,
        content: 'Here is the result.',
        timestamp: DateTime.now(),
        metadata: MessageMetadata(
          responseTime: '1.0s',
          sources: ['System'],
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, AlignmentDirectional.centerStart);
    });

    testWidgets('renders bot message with markdown content', (tester) async {
      final msg = ChatMessage(
        id: 'msg-4',
        role: MessageRole.assistant,
        content: 'The **answer** is 42.',
        timestamp: DateTime.now(),
        metadata: MessageMetadata(
          responseTime: '0.5s',
          sources: ['Waybills DB'],
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Markdown renders the text content
      expect(find.textContaining('answer'), findsOneWidget);
    });

    testWidgets('shows disambiguation card when needed', (tester) async {
      final msg = ChatMessage(
        id: 'msg-5',
        role: MessageRole.assistant,
        content: 'Which status do you mean?',
        timestamp: DateTime.now(),
        metadata: MessageMetadata(
          responseTime: '0.0s',
          sources: ['Waybills DB'],
          needsDisambiguation: true,
          disambiguationOptions: [
            DisambiguationOption(value: 'Waybill Status', label: 'Waybill Status'),
            DisambiguationOption(value: 'Delivery Status', label: 'Delivery Status'),
          ],
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Waybill Status'), findsOneWidget);
      expect(find.text('Delivery Status'), findsOneWidget);
    });

    testWidgets('shows clarification card when needed', (tester) async {
      final msg = ChatMessage(
        id: 'msg-6',
        role: MessageRole.assistant,
        content: 'Multiple sources available.',
        timestamp: DateTime.now(),
        originalQuery: 'dwell time query',
        metadata: MessageMetadata(
          responseTime: '0.1s',
          sources: ['System'],
          needsClarification: true,
          clarificationMessage: 'Choose a data source',
          clarificationOptions: [
            ClarificationOption(route: 'sql', label: 'Waybills DB'),
            ClarificationOption(route: 'csv', label: 'Dwell Time CSV'),
          ],
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Choose a data source'), findsOneWidget);
      expect(find.text('Waybills DB'), findsOneWidget);
      expect(find.text('Dwell Time CSV'), findsOneWidget);
    });

    testWidgets('shows metadata bar for normal response', (tester) async {
      final msg = ChatMessage(
        id: 'msg-7',
        role: MessageRole.assistant,
        content: 'Result here.',
        timestamp: DateTime.now(),
        metadata: MessageMetadata(
          responseTime: '2.5s',
          sources: ['Waybills DB'],
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        MessageBubble(
          message: msg,
          onDisambiguationSelect: (_) {},
          onClarificationSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2.5s'), findsOneWidget);
      expect(find.text('Waybills DB'), findsOneWidget);
    });
  });
}
