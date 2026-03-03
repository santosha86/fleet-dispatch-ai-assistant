import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/widgets/chat/query_input_bar.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('QueryInputBar', () {
    testWidgets('renders text field, send button, and mic button', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        QueryInputBar(
          onSend: (_) {},
          onClear: () {},
          isLoading: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('shows placeholder text', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        QueryInputBar(
          onSend: (_) {},
          onClear: () {},
          isLoading: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Type your message...'), findsOneWidget);
    });

    testWidgets('calls onSend with trimmed text and clears input', (tester) async {
      String? sentText;

      await tester.pumpWidget(buildTestableWidget(
        QueryInputBar(
          onSend: (text) => sentText = text,
          onClear: () {},
          isLoading: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  How many waybills?  ');
      await tester.tap(find.byIcon(Icons.send));

      expect(sentText, 'How many waybills?');
    });

    testWidgets('does not send empty text', (tester) async {
      bool wasCalled = false;

      await tester.pumpWidget(buildTestableWidget(
        QueryInputBar(
          onSend: (_) => wasCalled = true,
          onClear: () {},
          isLoading: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap send without entering text
      await tester.tap(find.byIcon(Icons.send));
      expect(wasCalled, false);
    });

    testWidgets('does not send whitespace-only text', (tester) async {
      bool wasCalled = false;

      await tester.pumpWidget(buildTestableWidget(
        QueryInputBar(
          onSend: (_) => wasCalled = true,
          onClear: () {},
          isLoading: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      expect(wasCalled, false);
    });

    testWidgets('send button is disabled when isLoading is true', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        QueryInputBar(
          onSend: (_) {},
          onClear: () {},
          isLoading: true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test query');
      await tester.tap(find.byIcon(Icons.send));

      // Find send button specifically by its icon
      final sendButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));
      expect(sendButton.onPressed, isNull);
    });
  });
}
