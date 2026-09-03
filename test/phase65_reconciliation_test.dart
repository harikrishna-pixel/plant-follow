import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/navigation/plant_workspace_tabs.dart';
import 'package:plantidentifier/navigation/plants_ia.dart';
import 'package:plantidentifier/navigation/v1_nav.dart';
import 'package:plantidentifier/services/diagnosis_mapper.dart';
import 'package:plantidentifier/services/identification_policy.dart';
import 'package:plantidentifier/services/identify_logic.dart';
import 'package:plantidentifier/services/plant_health_presenter.dart';
import 'package:plantidentifier/services/plant_timeline.dart';
import 'package:plantidentifier/services/progress_logic.dart';
import 'package:plantidentifier/services/recovery_logic.dart';
import 'package:plantidentifier/services/today_priority.dart';
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';
import 'package:plantidentifier/view/screens/camera/camera_entry_sheet.dart';
import 'package:plantidentifier/view/screens/diagnosis/plant_diagnosis_screen.dart';
import 'package:plantidentifier/model/data_model/reminder_model.dart';
import 'package:plantidentifier/view/screens/favourite_screen/plant_care_tab.dart';
import 'package:plantidentifier/view/screens/scan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Identification quota UX', () {
    test('does not show a free-scan counter', () {
      expect(IdentificationPolicy.showFreeScanCounter, isFalse);
      expect(IdentificationPolicy.visibleRemainingLabel(3), isNull);
      expect(IdentificationPolicy.visibleRemainingLabel(2), isNull);
    });

    test('normal identification is not blocked by legacy quota', () {
      expect(
        IdentificationPolicy.canStartIdentification(
          isSubscribed: false,
          freeScansRemaining: 0,
        ),
        isTrue,
      );
      expect(IdentificationPolicy.blockIdentifyOnLegacyQuota, isFalse);
    });
  });

  group('Identification parser safety', () {
    test('malformed response is a parser failure, not a plant', () {
      final attempt = IdentifyLogic.fromModelText('thanks!', '/tmp/a.jpg');
      expect(attempt.isSuccess, isFalse);
      expect(attempt.plant, isNull);
      expect(attempt.failure, IdentifyFailureKind.parser);
    });

    test('Unknown / empty names cannot become a confident plant', () {
      expect(
        IdentifyLogic.fromJson({
          'plant_name_common': 'Unknown',
        }, '/tmp/a.jpg').isSuccess,
        isFalse,
      );
      expect(
        IdentifyLogic.fromJson({
          'plant_name_common': '',
        }, '/tmp/a.jpg').isSuccess,
        isFalse,
      );
      expect(
        IdentifyLogic.fromJson({
          'error': 'not_a_plant',
        }, '/tmp/a.jpg').failure,
        IdentifyFailureKind.invalid,
      );
    });

    test('valid payload maps a plant and does not invent alternatives', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'plant_name_scientific': 'Epipremnum aureum',
        'identification_confidence': 'medium',
      }, '/tmp/pothos.jpg');
      expect(attempt.isSuccess, isTrue);
      expect(attempt.plant!.name, 'Pothos');
      expect(attempt.plant!.alternativeNames, isEmpty);
      expect(IdentifyLogic.displayName(attempt.plant!), 'Likely Pothos');
      expect(IdentifyLogic.isUncertain(attempt.plant!), isTrue);
    });

    test('alternatives only come from the model', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'low',
        'alternative_candidates': [
          {'common_name': 'Philodendron', 'scientific_name': 'Philodendron hederaceum'},
        ],
      }, '/tmp/p.jpg');
      expect(attempt.plant!.alternativeNames.single, contains('Philodendron'));
    });
  });

  group('Diagnosis safeguards', () {
    test('empty or error JSON cannot persist a diagnosis or recovery', () {
      expect(DiagnosisMapper.canPersist({}), isFalse);
      expect(DiagnosisMapper.canPersist({'error': 'unable_to_diagnose'}), isFalse);
      expect(
        DiagnosisMapper.tryDiagnosisFromGemini(
          json: {},
          plantId: 'p1',
          photoPath: '/tmp/a.jpg',
        ),
        isNull,
      );
    });

    test('valid diagnosis JSON can map without starting recovery', () {
      final diagnosis = DiagnosisMapper.tryDiagnosisFromGemini(
        json: {
          'plant_name': 'Pothos',
          'overall_condition': 'needs_attention',
          'confidence': 'high',
          'what_we_noticed': 'Dry leaf edges',
          'primary_issue': {
            'name': 'Underwatering',
            'explanation': 'Edges are crispy',
            'evidence': 'Brown tips',
          },
        },
        plantId: 'p1',
        photoPath: '/tmp/a.jpg',
      );
      expect(diagnosis, isNotNull);
      expect(diagnosis!.primaryIssue.name, 'Underwatering');
    });
  });

  group('Plant workspace', () {
    test('customer-facing tabs are Care Health Timeline About', () {
      expect(PlantWorkspaceTabs.labels, ['Care', 'Health', 'Timeline', 'About']);
      expect(PlantWorkspaceTabs.legacyLabels, isNot(contains('Care')));
      expect(PlantWorkspaceTabs.legacyLabels, contains('Basic'));
    });

    test('Health with no recovery is a neutral empty state', () {
      final view = PlantHealthPresenter.fromState(
        now: DateTime(2026, 9, 2),
        activeCase: null,
        diagnosis: null,
        outcomes: const [],
      );
      expect(view.hasActiveRecovery, isFalse);
      expect(view.headline, PlantHealthView.emptyHeadline);
      expect(view.headline.toLowerCase(), isNot(contains('healthy')));
    });

    test('Timeline reads existing plant events', () {
      final event = PlantEvent(
        id: 'e1',
        plantId: 'p1',
        eventType: PlantEventType.identification,
        timestamp: DateTime(2026, 9, 1),
        payload: {'name': 'Pothos'},
      );
      final item = PlantTimelineMapper.fromEvent(event);
      expect(item.title, 'Identified');
      expect(item.detail, 'Pothos');
    });
  });

  group('Plants IA and Me tools', () {
    test('Tasks and Scan History are not equal primary Plants tabs', () {
      expect(PlantsPrimaryIa.showTasksAsEqualTab, isFalse);
      expect(PlantsPrimaryIa.showScanHistoryAsEqualTab, isFalse);
    });

    test('Scan History remains a Me secondary tool', () {
      expect(MeSecondaryTools.titles, contains(MeSecondaryTools.scanHistory));
      expect(MeSecondaryTools.titles, contains(MeSecondaryTools.aiBotanist));
      expect(MeSecondaryTools.titles, contains(MeSecondaryTools.reminders));
    });
  });

  group('Bottom navigation', () {
    test('camera still opens Identify and Diagnose', () {
      expect(cameraScreenFor(CameraEntryMode.identify), isA<ScanScreen>());
      expect(
        cameraScreenFor(CameraEntryMode.diagnose),
        isA<PlantDiagnosisScreen>(),
      );
    });

    testWidgets('bar has Today Plants Camera Progress Me', (tester) async {
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
      for (final label in [
        'Today',
        'Plants',
        'Camera',
        'Progress',
        'Me',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('Progress projection', () {
    test('active recoveries and outcomes come from existing data', () {
      final opened = DateTime(2026, 8, 29);
      final active = RecoveryCase(
        id: 'c1',
        plantId: 'p1',
        diagnosisId: 'd1',
        treatmentId: 't1',
        openedAt: opened,
        status: RecoveryCaseStatus.awaitingDay3,
        day3DueAt: RecoveryLogic.day3DueAt(opened),
        day7DueAt: RecoveryLogic.day7DueAt(opened),
      );
      final outcome = RecoveryOutcome(
        id: 'o1',
        plantId: 'p1',
        recoveryCaseId: 'c0',
        result: OutcomeResult.recovered,
        closedAt: DateTime(2026, 9, 1),
        closeReason: 'check_in',
      );
      final snapshot = ProgressLogic.from(
        cases: [active],
        outcomes: [outcome],
        events: [
          PlantEvent(
            id: 'e1',
            plantId: 'p1',
            eventType: PlantEventType.careCompletion,
            timestamp: DateTime(2026, 9, 1),
            payload: {'careType': 'Watering'},
          ),
        ],
      );
      expect(snapshot.activeRecoveries.single.id, 'c1');
      expect(snapshot.recentOutcomes.single.result, OutcomeResult.recovered);
      expect(snapshot.recentProgress, isNotEmpty);
      expect(snapshot.isEmpty, isFalse);
    });

    test('empty snapshot does not fabricate progress', () {
      final snapshot = ProgressLogic.from(
        cases: const [],
        outcomes: const [],
        events: const [],
      );
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.activeRecoveries, isEmpty);
      expect(snapshot.recentOutcomes, isEmpty);
      expect(snapshot.recentProgress, isEmpty);
      expect(ProgressSnapshot.emptyTitle, 'Your progress starts here');
    });
  });

  group('Today still owns daily decisions', () {
    test('caps at 3 cards and recovery outranks care', () {
      final opened = DateTime(2026, 8, 29);
      final cases = [
        RecoveryCase(
          id: 'c1',
          plantId: 'p1',
          diagnosisId: 'd1',
          treatmentId: 't1',
          openedAt: opened,
          status: RecoveryCaseStatus.awaitingDay3,
          day3DueAt: RecoveryLogic.day3DueAt(opened),
          day7DueAt: RecoveryLogic.day7DueAt(opened),
        ),
      ];
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: cases,
        plantNames: {'p1': 'Pothos'},
        reminders: [
          PlantReminder(
            id: 'r1',
            plantName: 'Fern',
            taskType: 'Water',
            dateTime: DateTime(2026, 9, 1, 9),
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
      );
      expect(result.cards.length, lessThanOrEqualTo(TodayPriorityResolver.maxPrimaryCards));
      expect(result.cards.length, lessThanOrEqualTo(3));
      expect(result.cards.first.kind, TodayActionKind.recovery);
    });
  });

  test('care empty copy is unchanged', () {
    expect(PlantCareTab.emptyTitle, 'No care schedule yet');
  });
}
