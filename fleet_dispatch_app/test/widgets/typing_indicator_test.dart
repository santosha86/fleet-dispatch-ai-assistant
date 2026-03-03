import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/widgets/chat/typing_indicator.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('TypingIndicator', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const TypingIndicator(),
      ));

      // Advance past all staggered Future.delayed timers (3 dots x 150ms each)
      await tester.pump(const Duration(milliseconds: 500));

      // The widget should render 3 bouncing dots
      expect(find.byType(TypingIndicator), findsOneWidget);

      // Clean up: remove widget so animation controllers are disposed
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('disposes cleanly without errors', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const TypingIndicator(),
      ));

      // Advance past all staggered timers so no pending timers remain
      await tester.pump(const Duration(milliseconds: 500));

      // Remove the widget - should dispose animation controllers cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
