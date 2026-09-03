import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/navigation/plant_workspace_tabs.dart';
import 'package:plantidentifier/navigation/v1_nav.dart';
import 'package:plantidentifier/services/identification_policy.dart';
import 'package:plantidentifier/services/plant_health_presenter.dart';
import 'package:plantidentifier/services/today_priority.dart';
import 'package:plantidentifier/theme/plantfollow_colors.dart';
import 'package:plantidentifier/theme/plantfollow_metrics.dart';
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';
import 'package:plantidentifier/view/screens/today/today_feed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('bottom bar stays Today Plants Camera Progress Me', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: V1BottomBar(
            currentIndex: V1Nav.todayIndex,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Ask Me'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('Today empty state is compact and offers View plants', (tester) async {
    var viewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayEmptyState(onViewPlants: () => viewed = true),
        ),
      ),
    );
    expect(find.text(TodayPriorityResult.emptyTitle), findsOneWidget);
    expect(find.text(TodayPriorityResult.emptySubtitle), findsOneWidget);
    await tester.tap(find.text('View plants'));
    expect(viewed, isTrue);
  });

  test('Plant Detail tabs stay Care Health Timeline About', () {
    expect(PlantWorkspaceTabs.labels, ['Care', 'Health', 'Timeline', 'About']);
    expect(PlantWorkspaceTabs.legacyLabels, isNot(contains('Care')));
  });

  test('health empty copy is not an AI health claim', () {
    expect(PlantHealthView.emptyHeadline, 'No active recovery');
    expect(
      PlantHealthView.emptyBody,
      'This plant has no active recovery plan.',
    );
    expect(PlantHealthView.emptyBody.toLowerCase(), isNot(contains('healthy')));
  });

  test('Identify does not show a free-scan quota', () {
    expect(IdentificationPolicy.showFreeScanCounter, isFalse);
  });

  test('design tokens use a 4pt spacing grid and restrained green', () {
    expect(PlantFollowSpacing.screen, 20);
    expect(PlantFollowRadius.card, 16);
    expect(PlantFollowRadius.sheet, 24);
    expect(PlantFollowColors.primary, const Color(0xFF1F6F35));
    expect(PlantFollowColors.background, const Color(0xFFF7F9F5));
  });
}
