import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/model/data_model/reminder_model.dart';
import 'package:plantidentifier/navigation/v1_nav.dart';
import 'package:plantidentifier/navigation/v1_shell.dart';
import 'package:plantidentifier/services/recovery_logic.dart';
import 'package:plantidentifier/services/today_priority.dart';
import 'package:plantidentifier/view/screens/camera/camera_entry_sheet.dart';
import 'package:plantidentifier/view/screens/diagnosis/plant_diagnosis_screen.dart';
import 'package:plantidentifier/view/screens/home_screen.dart';
import 'package:plantidentifier/view/screens/scan_screen.dart';
import 'package:plantidentifier/view/screens/today/today_feed.dart';
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';

RecoveryCase _recoveryCase({
  String id = 'case-1',
  String plantId = 'plant-1',
  RecoveryCaseStatus status = RecoveryCaseStatus.awaitingDay3,
  DateTime? openedAt,
  DateTime? day3DueAt,
  DateTime? day7DueAt,
  DateTime? day3CompletedAt,
  DateTime? deferredUntil,
}) {
  final opened = openedAt ?? DateTime(2026, 8, 29);
  return RecoveryCase(
    id: id,
    plantId: plantId,
    diagnosisId: 'diag-1',
    treatmentId: 'treat-1',
    openedAt: opened,
    status: status,
    day3DueAt: day3DueAt ?? RecoveryLogic.day3DueAt(opened),
    day7DueAt: day7DueAt ?? RecoveryLogic.day7DueAt(opened),
    day3CompletedAt: day3CompletedAt,
    deferredUntil: deferredUntil,
  );
}

PlantReminder _reminder({
  String id = 'rem-1',
  String plantName = 'Pothos',
  DateTime? dateTime,
  bool completed = false,
}) {
  return PlantReminder(
    id: id,
    plantName: plantName,
    taskType: 'Water',
    dateTime: dateTime ?? DateTime(2026, 9, 1, 9),
    createdAt: DateTime(2026, 8, 20),
    isCompleted: completed,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Today priority', () {
    test('recovery due outranks care', () {
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: [_recoveryCase()],
        plantNames: {'plant-1': 'Monstera'},
        diagnosisSummaries: {'diag-1': 'dry leaf edges'},
        reminders: [
          _reminder(id: 'r1', plantName: 'Pothos'),
          _reminder(
            id: 'r2',
            plantName: 'Fern',
            dateTime: DateTime(2026, 9, 1, 8),
          ),
        ],
      );
      expect(result.cards, isNotEmpty);
      expect(result.cards.first.kind, TodayActionKind.recovery);
      expect(result.cards.first.recoveryCaseId, 'case-1');
      expect(result.cards.first.checkInStage, CheckInStage.day3);
      expect(result.cards.first.ctaLabel, 'Check now');
      expect(result.cards.first.title, contains('Monstera'));
    });

    test('enforces a maximum of 3 primary cards by priority', () {
      final cases = [
        _recoveryCase(id: 'c-a', plantId: 'p-a'),
        _recoveryCase(id: 'c-b', plantId: 'p-b'),
        _recoveryCase(id: 'c-c', plantId: 'p-c'),
      ];
      final reminders = [
        _reminder(id: 'r1'),
        _reminder(id: 'r2', plantName: 'Fern'),
        _reminder(id: 'r3', plantName: 'Ficus'),
      ];
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: cases,
        plantNames: {'p-a': 'Monstera', 'p-b': 'Snake plant', 'p-c': 'Pothos'},
        reminders: reminders,
        weather: const TodayWeatherSnapshot(temperatureC: 40),
        plantWeatherContexts: const [
          PlantWeatherContext.unknown,
          PlantWeatherContext.indoor,
        ],
      );
      expect(result.cards.length, TodayPriorityResolver.maxPrimaryCards);
      expect(result.cards.length, 3);
      expect(
        result.cards.every((c) => c.kind == TodayActionKind.recovery),
        isTrue,
      );
      expect(
        result.cards.any((c) => c.kind == TodayActionKind.weather),
        isFalse,
      );
      expect(result.cards.any((c) => c.kind == TodayActionKind.care), isFalse);
    });

    test(
      'unknown plant context does not generate a critical outdoor weather card',
      () {
        final result = TodayPriorityResolver.resolve(
          now: DateTime(2026, 9, 1, 10),
          cases: const [],
          plantNames: {'plant-1': 'Monstera'},
          weather: const TodayWeatherSnapshot(temperatureC: 40),
          plantWeatherContexts: const [PlantWeatherContext.unknown],
        );
        expect(result.isEmpty, isTrue);
        expect(
          TodayPriorityResolver.shouldShowCriticalWeather(
            weather: const TodayWeatherSnapshot(temperatureC: -1),
            plantContexts: const [PlantWeatherContext.unknown],
          ),
          isFalse,
        );
      },
    );

    test(
      'indoor plant context does not generate a critical outdoor weather card',
      () {
        final result = TodayPriorityResolver.resolve(
          now: DateTime(2026, 9, 1, 10),
          cases: [_recoveryCase()],
          plantNames: {'plant-1': 'Monstera'},
          reminders: [_reminder()],
          weather: const TodayWeatherSnapshot(temperatureC: 1),
          plantWeatherContexts: const [PlantWeatherContext.indoor],
        );
        expect(
          result.cards.any((c) => c.kind == TodayActionKind.weather),
          isFalse,
        );
        expect(result.cards.first.kind, TodayActionKind.recovery);
      },
    );

    test(
      'weather stays suppressed when current plants have no placement field',
      () {
        expect(
          TodayPriorityResolver.contextForCurrentPlant(),
          PlantWeatherContext.unknown,
        );
        final result = TodayPriorityResolver.resolve(
          now: DateTime(2026, 9, 1, 10),
          cases: const [],
          plantNames: {'plant-1': 'Monstera'},
          weather: const TodayWeatherSnapshot(temperatureC: 42),
          plantWeatherContexts: [
            TodayPriorityResolver.contextForCurrentPlant(),
          ],
        );
        expect(result.cards, isEmpty);
      },
    );

    test(
      'recovery outranks critical weather for outdoor plants',
      () {
        final result = TodayPriorityResolver.resolve(
          now: DateTime(2026, 9, 1, 10),
          cases: [_recoveryCase()],
          plantNames: {'plant-1': 'Monstera'},
          reminders: [_reminder()],
          weather: const TodayWeatherSnapshot(temperatureC: 40),
          plantWeatherContexts: const [PlantWeatherContext.outdoorPotted],
        );
        expect(result.cards.first.kind, TodayActionKind.recovery);
        expect(
          result.cards.any((c) => c.kind == TodayActionKind.weather),
          isTrue,
        );
      },
    );

    test(
      'known outdoor placement can surface critical weather when nothing else is due',
      () {
        final result = TodayPriorityResolver.resolve(
          now: DateTime(2026, 9, 1, 10),
          cases: const [],
          plantNames: {'plant-1': 'Monstera'},
          weather: const TodayWeatherSnapshot(temperatureC: 40),
          plantWeatherContexts: const [PlantWeatherContext.outdoorPotted],
        );
        expect(result.cards, isNotEmpty);
        expect(result.cards.first.kind, TodayActionKind.weather);
      },
    );

    test('empty state when nothing is due', () {
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: [
          _recoveryCase(
            day3DueAt: DateTime(2026, 9, 4),
            day7DueAt: DateTime(2026, 9, 8),
          ),
        ],
        plantNames: {'plant-1': 'Monstera'},
        reminders: [_reminder(completed: true)],
        weather: const TodayWeatherSnapshot(temperatureC: 22),
      );
      expect(result.isEmpty, isTrue);
      expect(result.cards, isEmpty);
    });

    test('overdue recovery still surfaces calmly', () {
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 5, 10),
        cases: [_recoveryCase()],
        plantNames: {'plant-1': 'Monstera'},
      );
      expect(result.cards.single.kind, TodayActionKind.recovery);
      expect(result.cards.single.overdue, isTrue);
      expect(result.cards.single.ctaLabel, 'Check now');
      expect(
        result.cards.single.subtitle.toLowerCase(),
        isNot(contains('overdue')),
      );
      expect(
        result.cards.single.subtitle.toLowerCase(),
        isNot(contains('fail')),
      );
    });

    test('deferred recovery is hidden until the later day', () {
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: [_recoveryCase(deferredUntil: DateTime(2026, 9, 3, 9))],
        plantNames: {'plant-1': 'Monstera'},
      );
      expect(result.isEmpty, isTrue);
    });
  });

  group('Recovery routing', () {
    test('Today recovery card maps onto RecoveryCheckInScreen inputs', () {
      final recoveryCase = _recoveryCase();
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: [recoveryCase],
        plantNames: {'plant-1': 'Monstera'},
      );
      final action = result.cards.single;
      expect(action.recoveryCaseId, recoveryCase.id);
      expect(action.plantId, recoveryCase.plantId);
      expect(action.checkInStage, CheckInStage.day3);

      const plantName = 'Monstera';
      expect(action.title, contains(plantName));
    });

    testWidgets('Check now invokes the recovery action', (tester) async {
      TodayAction? tapped;
      final action = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: [_recoveryCase()],
        plantNames: {'plant-1': 'Monstera'},
      ).cards.single;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayActionCard(
              action: action,
              onPressed: () => tapped = action,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Check now'));
      await tester.pump();
      expect(tapped?.recoveryCaseId, 'case-1');
      expect(tapped?.checkInStage, CheckInStage.day3);
    });
  });

  group('Empty state UI', () {
    testWidgets('shows the designed empty copy when there are no actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodayFeed(actions: [], onPrimaryAction: _noop),
          ),
        ),
      );
      expect(find.text(TodayPriorityResult.emptyTitle), findsOneWidget);
      expect(find.text(TodayPriorityResult.emptySubtitle), findsOneWidget);
      expect(find.text('Check now'), findsNothing);
    });
  });

  group('Camera selector', () {
    test('Identify routes to the existing Identify screen', () {
      expect(cameraScreenFor(CameraEntryMode.identify), isA<ScanScreen>());
    });

    test('Diagnose routes to the existing Diagnose screen', () {
      expect(
        cameraScreenFor(CameraEntryMode.diagnose),
        isA<PlantDiagnosisScreen>(),
      );
      final screen =
          cameraScreenFor(CameraEntryMode.diagnose) as PlantDiagnosisScreen;
      expect(screen.plant, isNull);
    });

    testWidgets('sheet offers Identify and Diagnose', (tester) async {
      CameraEntryMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<CameraEntryMode>(
                    context: context,
                    builder: (_) => const CameraEntrySheet(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Identify'), findsOneWidget);
      expect(find.text('Diagnose'), findsOneWidget);
      await tester.tap(find.text('Diagnose'));
      await tester.pumpAndSettle();
      expect(selected, CameraEntryMode.diagnose);
    });
  });

  group('Navigation', () {
    test('primary V1 destinations are Today, Plants, Progress, and Me', () {
      expect(V1Nav.primaryLabels, ['Today', 'Plants', 'Progress', 'Me']);
      expect(V1Nav.askMeIsPrimaryDestination, isFalse);
      expect(V1Nav.cameraIsPersistentTab, isFalse);
      expect(MeSecondaryTools.titles, contains(MeSecondaryTools.aiBotanist));
      expect(MeSecondaryTools.titles, contains(MeSecondaryTools.scanHistory));
    });

    test('Restore Purchase returns to the V1 tab shell, not HomeScreen', () {
      expect(V1Nav.restorePurchaseUsesTabShell, isTrue);
      expect(V1Shell.restoreAfterPurchase(), isA<BottomNavExample>());
      expect(V1Shell.restoreAfterPurchase(), isNot(isA<HomeScreen>()));
    });

    testWidgets('bottom bar shows Today Plants Camera Progress Me', (
      tester,
    ) async {
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
  });
}

void _noop(TodayAction action) {}
