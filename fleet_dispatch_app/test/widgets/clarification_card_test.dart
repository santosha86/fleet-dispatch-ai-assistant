import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/clarification_option.dart';
import 'package:fleet_dispatch_app/widgets/chat/clarification_card.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ClarificationCard', () {
    testWidgets('renders custom message text', (tester) async {
      final options = [
        ClarificationOption(route: 'sql', label: 'Waybills DB'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        ClarificationCard(
          message: 'Which data source would you like?',
          options: options,
          originalQuery: 'test query',
          onSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Which data source would you like?'), findsOneWidget);
    });

    testWidgets('renders default message when empty', (tester) async {
      final options = [
        ClarificationOption(route: 'sql', label: 'DB'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        ClarificationCard(
          message: '',
          options: options,
          originalQuery: 'test',
          onSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Falls back to l10n.selectDataSource
      expect(find.text('Please select a data source:'), findsOneWidget);
    });

    testWidgets('renders all option buttons with labels', (tester) async {
      final options = [
        ClarificationOption(route: 'sql', label: 'Waybills Database'),
        ClarificationOption(route: 'csv', label: 'Dwell Time CSV'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        ClarificationCard(
          message: 'Choose source',
          options: options,
          originalQuery: 'dwell time query',
          onSelect: (r, q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Waybills Database'), findsOneWidget);
      expect(find.text('Dwell Time CSV'), findsOneWidget);
    });

    testWidgets('calls onSelect with route and originalQuery', (tester) async {
      String? selectedRoute;
      String? selectedQuery;
      final options = [
        ClarificationOption(route: 'sql', label: 'Waybills DB'),
        ClarificationOption(route: 'csv', label: 'Dwell Time'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        ClarificationCard(
          message: 'Choose',
          options: options,
          originalQuery: 'my original question',
          onSelect: (route, query) {
            selectedRoute = route;
            selectedQuery = query;
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dwell Time'));

      expect(selectedRoute, 'csv');
      expect(selectedQuery, 'my original question');
    });
  });
}
