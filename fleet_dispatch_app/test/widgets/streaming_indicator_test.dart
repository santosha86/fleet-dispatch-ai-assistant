import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/widgets/chat/streaming_indicator.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('StreamingIndicator', () {
    testWidgets('shows phase text when provided', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const StreamingIndicator(
          content: '',
          phase: 'Retrieving documents...',
        ),
      ));
      // Use pump() instead of pumpAndSettle() because CircularProgressIndicator
      // has an ongoing animation that never settles.
      await tester.pump();

      expect(find.text('Retrieving documents...'), findsOneWidget);
    });

    testWidgets('shows content when provided', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const StreamingIndicator(
          content: 'The answer is 42.',
          phase: '',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('The answer is 42.'), findsOneWidget);
    });

    testWidgets('shows both phase and content', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const StreamingIndicator(
          content: 'Streaming answer text',
          phase: 'Analyzing...',
        ),
      ));
      // Use pump() - CircularProgressIndicator prevents settle
      await tester.pump();

      expect(find.text('Analyzing...'), findsOneWidget);
      expect(find.text('Streaming answer text'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when phase is set', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const StreamingIndicator(
          content: '',
          phase: 'Loading...',
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not show spinner when phase is empty', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const StreamingIndicator(
          content: 'Some text',
          phase: '',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
