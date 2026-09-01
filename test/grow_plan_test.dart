import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/care_rule.dart';
import 'package:plantidentifier/model/data_model/grow_plan.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/services/grow_logic.dart';
import 'package:plantidentifier/services/plant_timeline.dart';
import 'package:plantidentifier/services/recovery_logic.dart';
import 'package:plantidentifier/services/today_priority.dart';

Plant _plant({
  String id = 'plant-a',
  String name = 'Tomato',
  bool harvestable = false,
  String? cropId,
}) {
  return Plant(
    id: id,
    name: name,
    scientificName: 'Solanum lycopersicum',
    description: 'A fruiting crop.',
    taxonomy: const {},
    nativeRegion: '',
    growthSeason: '',
    toxicity: '',
    careGuide: const {},
    healthScan: '',
    commonPests: '',
    commonDiseases: '',
    usage: '',
    funFact: '',
    isHarvestable: harvestable,
    cropId: cropId,
  );
}

GrowPlan _plan({
  String id = 'plan-a',
  String plantId = 'plant-a',
  String cropId = CropCatalog.tomatoId,
  HarvestRepeat? harvestRepeat,
  GrowPlanStatus status = GrowPlanStatus.active,
  List<GrowAnchor> anchors = const [],
}) {
  final crop = CropCatalog.byId(cropId);
  return GrowPlan(
    id: id,
    plantId: plantId,
    cropId: crop.id,
    createdAt: DateTime(2026, 8, 1),
    harvestRepeat: harvestRepeat ?? crop.harvestRepeat,
    status: status,
    anchors: anchors,
  );
}

CareRule _care({String plantId = 'plant-a'}) {
  return CareRule(
    id: 'rule-1',
    plantId: plantId,
    careType: 'Watering',
    baseIntervalDays: 7,
    nextDueAt: DateTime(2026, 9, 1, 9),
  );
}

RecoveryCase _recovery() {
  final opened = DateTime(2026, 8, 29);
  return RecoveryCase(
    id: 'case-1',
    plantId: 'plant-a',
    diagnosisId: 'diag-1',
    treatmentId: 'treat-1',
    openedAt: opened,
    status: RecoveryCaseStatus.awaitingDay3,
    day3DueAt: RecoveryLogic.day3DueAt(opened),
    day7DueAt: RecoveryLogic.day7DueAt(opened),
  );
}

void main() {
  group('Harvestable eligibility', () {
    test('existing plants default to non-harvestable', () {
      final plant = _plant();
      expect(plant.isHarvestable, isFalse);
      expect(GrowLogic.shouldShowGrowPlan(plant), isFalse);
    });

    test('harvestable plant can have a grow plan', () {
      final plant = _plant(harvestable: true, cropId: CropCatalog.tomatoId);
      expect(GrowLogic.shouldShowGrowPlan(plant), isTrue);
      final plan = _plan();
      expect(plan.plantId, plant.id);
      expect(plan.harvestRepeat, HarvestRepeat.repeated);
    });
  });

  group('Anchor events', () {
    test('confirmed anchor persists', () {
      final sowed = DateTime(2026, 9, 1);
      final plan = GrowLogic.applyAnchor(_plan(), GrowAnchorType.sowed, sowed);
      expect(plan.anchor(GrowAnchorType.sowed)?.confirmedAt, sowed);
    });

    test('anchor recalculates future derived stages', () {
      final sowed = DateTime(2026, 9, 1);
      var plan = GrowLogic.applyAnchor(
        _plan(cropId: CropCatalog.genericId),
        GrowAnchorType.sowed,
        sowed,
      );
      var derived = GrowLogic.derive(plan);
      final seedling = derived.firstWhere((s) => s.stage == GrowStage.seedling);
      expect(seedling.confirmed, isFalse);
      expect(seedling.expectedStart, DateTime(2026, 9, 8));

      plan = GrowLogic.applyAnchor(
        plan,
        GrowAnchorType.germinated,
        DateTime(2026, 9, 10),
      );
      derived = GrowLogic.derive(plan);
      expect(
        derived.firstWhere((s) => s.stage == GrowStage.sown).confirmedAt,
        sowed,
      );
      expect(
        derived.firstWhere((s) => s.stage == GrowStage.seedling).confirmedAt,
        DateTime(2026, 9, 10),
      );
      expect(
        derived
            .firstWhere((s) => s.stage == GrowStage.vegetative)
            .expectedStart,
        DateTime(2026, 9, 24),
      );
    });

    test(
      'past confirmed anchors remain unchanged when another anchor is added',
      () {
        var plan = GrowLogic.applyAnchor(
          _plan(cropId: CropCatalog.genericId),
          GrowAnchorType.sowed,
          DateTime(2026, 9, 1),
        );
        plan = GrowLogic.applyAnchor(
          plan,
          GrowAnchorType.germinated,
          DateTime(2026, 9, 10),
        );
        plan = GrowLogic.applyAnchor(
          plan,
          GrowAnchorType.sowed,
          DateTime(2026, 8, 20),
        );
        expect(
          plan.anchor(GrowAnchorType.sowed)?.confirmedAt,
          DateTime(2026, 8, 20),
        );
        expect(
          plan.anchor(GrowAnchorType.germinated)?.confirmedAt,
          DateTime(2026, 9, 10),
        );
        final derived = GrowLogic.derive(plan);
        expect(
          derived.firstWhere((s) => s.stage == GrowStage.seedling).confirmedAt,
          DateTime(2026, 9, 10),
        );
      },
    );
  });

  group('Plant isolation', () {
    test('Plant A grow plan never appears on Plant B', () {
      final plantA = _plant(id: 'plant-a', harvestable: true);
      final plantB = _plant(id: 'plant-b', name: 'Lettuce', harvestable: true);
      final planA = GrowLogic.applyAnchor(
        _plan(plantId: 'plant-a', cropId: CropCatalog.tomatoId),
        GrowAnchorType.germinated,
        DateTime(2026, 8, 1),
      );
      final now = DateTime(2026, 9, 1);
      expect(
        GrowLogic.dueAction(now: now, plant: plantA, plan: planA),
        isNotNull,
      );
      expect(GrowLogic.dueAction(now: now, plant: plantB, plan: planA), isNull);
      final actions = GrowLogic.dueActions(
        now: now,
        plants: [plantA, plantB],
        plans: [planA],
      );
      expect(actions.every((a) => a.plantId == 'plant-a'), isTrue);
      expect(actions.any((a) => a.plantId == 'plant-b'), isFalse);
    });
  });

  group('Milestones and harvest', () {
    test('confirmed stage creates a readable plant event', () {
      final event = GrowLogic.milestoneEvent(
        plantId: 'plant-a',
        type: GrowAnchorType.germinated,
        now: DateTime(2026, 9, 1),
      );
      expect(event.eventType, PlantEventType.milestone);
      expect(event.payload['title'], 'Sprouted');
      expect(PlantTimelineMapper.fromEvent(event).title, 'Sprouted');
    });

    test('harvest record appends a harvest event', () {
      final harvest = HarvestRecord(
        id: 'h1',
        plantId: 'plant-a',
        growPlanId: 'plan-a',
        timestamp: DateTime(2026, 9, 1),
        quantity: 3,
        unit: 'count',
      );
      final event = GrowLogic.harvestEvent(
        harvest: harvest,
        firstHarvest: true,
      );
      expect(event.eventType, PlantEventType.harvest);
      expect(event.payload['harvestId'], 'h1');
      expect(PlantTimelineMapper.fromEvent(event).title, 'Harvest recorded');
    });

    test(
      'repeated harvest is supported and first harvest does not close the plan',
      () {
        var plan = GrowLogic.applyAnchor(
          _plan(cropId: CropCatalog.tomatoId),
          GrowAnchorType.firstHarvest,
          DateTime(2026, 9, 1),
        );
        expect(plan.status, GrowPlanStatus.active);
        expect(plan.harvestRepeat, HarvestRepeat.repeated);

        final first = HarvestRecord(
          id: 'h1',
          plantId: 'plant-a',
          growPlanId: plan.id,
          timestamp: DateTime(2026, 9, 1),
        );
        final second = HarvestRecord(
          id: 'h2',
          plantId: 'plant-a',
          growPlanId: plan.id,
          timestamp: DateTime(2026, 9, 12),
        );
        expect(
          GrowLogic.harvestEvent(harvest: first, firstHarvest: true).eventType,
          PlantEventType.harvest,
        );
        expect(
          GrowLogic.harvestEvent(
            harvest: second,
            firstHarvest: false,
          ).eventType,
          PlantEventType.harvest,
        );
        expect(plan.status, isNot(GrowPlanStatus.completed));
      },
    );
  });

  group('Timeline grow labels', () {
    test('grow and harvest events render with readable labels', () {
      final events = [
        GrowLogic.milestoneEvent(
          plantId: 'plant-a',
          type: GrowAnchorType.sowed,
          now: DateTime(2026, 8, 1),
        ),
        GrowLogic.milestoneEvent(
          plantId: 'plant-a',
          type: GrowAnchorType.transplanted,
          now: DateTime(2026, 8, 20),
        ),
        GrowLogic.milestoneEvent(
          plantId: 'plant-a',
          type: GrowAnchorType.floweringStarted,
          now: DateTime(2026, 9, 1),
        ),
        GrowLogic.planCompletedEvent(
          plantId: 'plant-a',
          now: DateTime(2026, 9, 20),
        ),
      ];
      final items = PlantTimelineMapper.itemsForPlant(
        plantId: 'plant-a',
        events: events,
      );
      expect(items.map((e) => e.title), [
        'Grow plan completed',
        'Flowering started',
        'Transplanted',
        'Sowed',
      ]);
      expect(items.every((e) => !e.title.contains('_')), isTrue);
    });
  });

  group('Today grow actions', () {
    final tomato = _plant(harvestable: true, cropId: CropCatalog.tomatoId);
    final transplantedDue = GrowLogic.applyAnchor(
      _plan(cropId: CropCatalog.tomatoId),
      GrowAnchorType.germinated,
      DateTime(2026, 8, 1),
    );
    final now = DateTime(2026, 9, 1, 10);

    test('meaningful due grow action can surface', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-a': 'Tomato'},
        growActions: GrowLogic.dueActions(
          now: now,
          plants: [tomato],
          plans: [transplantedDue],
        ),
      );
      expect(result.cards, isNotEmpty);
      expect(result.cards.first.kind, TodayActionKind.grow);
      expect(result.cards.first.title, contains('Transplant'));
    });

    test('non-harvestable plant does not create grow Today cards', () {
      final houseplant = _plant(harvestable: false);
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-a': 'Tomato'},
        growActions: GrowLogic.dueActions(
          now: now,
          plants: [houseplant],
          plans: [transplantedDue],
        ),
      );
      expect(result.cards.any((c) => c.kind == TodayActionKind.grow), isFalse);
    });

    test('recovery still outranks Grow Plan', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: [_recovery()],
        plantNames: {'plant-a': 'Tomato'},
        growActions: GrowLogic.dueActions(
          now: now,
          plants: [tomato],
          plans: [transplantedDue],
        ),
      );
      expect(result.cards.first.kind, TodayActionKind.recovery);
    });

    test('care still outranks routine grow milestone', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-a': 'Tomato'},
        careRules: [_care()],
        growActions: GrowLogic.dueActions(
          now: now,
          plants: [tomato],
          plans: [transplantedDue],
        ),
      );
      expect(result.cards.first.kind, TodayActionKind.care);
      expect(result.cards.any((c) => c.kind == TodayActionKind.grow), isTrue);
    });

    test('global maximum remains 3 cards', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: [_recovery()],
        plantNames: {'plant-a': 'Tomato'},
        careRules: [_care()],
        growActions: GrowLogic.dueActions(
          now: now,
          plants: [tomato],
          plans: [transplantedDue],
        ),
        milestones: [
          TodayMilestoneCandidate(
            id: 'm1',
            plantId: 'plant-a',
            title: 'Tomato',
            subtitle: 'looking healthier',
            timestamp: now,
          ),
        ],
      );
      expect(result.cards.length, 3);
      expect(
        result.cards.any((c) => c.kind == TodayActionKind.milestone),
        isFalse,
      );
    });
  });

  group('Predicted stage copy', () {
    test('does not present an estimated stage as certain', () {
      var plan = GrowLogic.applyAnchor(
        _plan(cropId: CropCatalog.tomatoId),
        GrowAnchorType.transplanted,
        DateTime(2026, 8, 10),
      );
      final view = GrowLogic.viewFor(plan: plan, now: DateTime(2026, 9, 1));
      expect(view.label, 'Likely flowering soon');
      expect(view.confirmed, isFalse);
    });
  });
}
