import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/disambiguation_option.dart';
import 'package:fleet_dispatch_app/widgets/chat/disambiguation_card.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('DisambiguationCard', () {
    testWidgets('renders all options as buttons', (tester) async {
      final options = [
        DisambiguationOption(value: 'Waybill Status', label: 'Waybill Status'),
        DisambiguationOption(value: 'Delivery Status', label: 'Delivery Status'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DisambiguationCard(
          options: options,
          onSelect: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Waybill Status'), findsOneWidget);
      expect(find.text('Delivery Status'), findsOneWidget);
    });

    testWidgets('displays select option header text', (tester) async {
      final options = [
        DisambiguationOption(value: 'opt1', label: 'Option 1'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DisambiguationCard(
          options: options,
          onSelect: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Please select an option:'), findsOneWidget);
    });

    testWidgets('calls onSelect with option value when tapped', (tester) async {
      String? selectedValue;
      final options = [
        DisambiguationOption(value: 'Waybill Status', label: 'Waybill Status'),
        DisambiguationOption(value: 'Delivery Status', label: 'Delivery Status'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DisambiguationCard(
          options: options,
          onSelect: (value) => selectedValue = value,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delivery Status'));
      expect(selectedValue, 'Delivery Status');
    });

    testWidgets('uses displayText for button label', (tester) async {
      final options = [
        DisambiguationOption(value: 'raw_val', label: 'Nice Display'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DisambiguationCard(
          options: options,
          onSelect: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // displayText prefers label over value
      expect(find.text('Nice Display'), findsOneWidget);
      expect(find.text('raw_val'), findsNothing);
    });
  });
}
