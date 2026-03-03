import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/category.dart';
import 'package:fleet_dispatch_app/widgets/chat/category_chip_bar.dart';
import '../helpers/test_helpers.dart';

void main() {
  final testCategories = AsyncValue.data([
    Category(
      id: 'ops',
      label: 'Operations',
      icon: 'Truck',
      queries: ['How many active waybills?', 'Show delivery stats'],
    ),
    Category(
      id: 'waybills',
      label: 'Waybills',
      icon: 'FileText',
      queries: ['List pending waybills', 'Track waybill status'],
    ),
    Category(
      id: 'analytics',
      label: 'Analytics',
      icon: 'BarChart',
      queries: ['Monthly trends'],
    ),
  ]);

  group('CategoryChipBar', () {
    testWidgets('renders category chips from data', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: testCategories,
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Operations'), findsOneWidget);
      expect(find.text('Waybills'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
    });

    testWidgets('shows nothing during loading', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: const AsyncValue.loading(),
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Operations'), findsNothing);
    });

    testWidgets('shows nothing on error', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: AsyncValue.error(Exception('fail'), StackTrace.current),
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Operations'), findsNothing);
    });

    testWidgets('tapping chip expands queries list', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: testCategories,
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Queries should not be visible initially
      expect(find.text('How many active waybills?'), findsNothing);

      // Tap Operations chip
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();

      // Queries should now be visible
      expect(find.text('How many active waybills?'), findsOneWidget);
      expect(find.text('Show delivery stats'), findsOneWidget);
    });

    testWidgets('tapping same chip collapses queries', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: testCategories,
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      expect(find.text('How many active waybills?'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      expect(find.text('How many active waybills?'), findsNothing);
    });

    testWidgets('tapping different chip switches queries', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: testCategories,
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Expand Operations
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      expect(find.text('How many active waybills?'), findsOneWidget);
      expect(find.text('List pending waybills'), findsNothing);

      // Switch to Waybills
      await tester.tap(find.text('Waybills'));
      await tester.pumpAndSettle();
      expect(find.text('How many active waybills?'), findsNothing);
      expect(find.text('List pending waybills'), findsOneWidget);
    });

    testWidgets('tapping query calls onQueryTap and collapses', (tester) async {
      String? tappedQuery;

      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: testCategories,
          onQueryTap: (q) => tappedQuery = q,
        ),
      ));
      await tester.pumpAndSettle();

      // Expand Operations
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();

      // Tap a query
      await tester.tap(find.text('How many active waybills?'));
      await tester.pumpAndSettle();

      expect(tappedQuery, 'How many active waybills?');
      // Should collapse after tapping
      expect(find.text('How many active waybills?'), findsNothing);
    });

    testWidgets('shows empty widget for empty categories', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        CategoryChipBar(
          categories: const AsyncValue.data([]),
          onQueryTap: (q) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink
      expect(find.byType(ActionChip), findsNothing);
    });
  });
}
