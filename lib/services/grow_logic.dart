import '../model/data_model/grow_plan.dart';
import '../model/data_model/plant_event.dart';
import '../model/data_model/plant_model.dart';

class DerivedStage {
  final GrowStage stage;
  final DateTime? expectedStart;
  final bool confirmed;
  final DateTime? confirmedAt;

  const DerivedStage({
    required this.stage,
    this.expectedStart,
    this.confirmed = false,
    this.confirmedAt,
  });
}

class GrowDueAction {
  final String id;
  final String plantId;
  final String title;
  final String subtitle;
  final DateTime sortTime;
  final String ctaLabel;

  const GrowDueAction({
    required this.id,
    required this.plantId,
    required this.title,
    required this.subtitle,
    required this.sortTime,
    this.ctaLabel = 'View plan',
  });
}

class GrowStageView {
  final String label;
  final bool confirmed;
  final String nextLabel;
  final GrowStage? currentStage;
  final List<GrowAnchorType> nextConfirmations;

  const GrowStageView({
    required this.label,
    required this.confirmed,
    required this.nextLabel,
    this.currentStage,
    this.nextConfirmations = const [],
  });
}

/// Deterministic grow-plan derivation. No Hive, no AI.
class GrowLogic {
  GrowLogic._();

  static const harvestNagCooldown = Duration(days: 7);

  static bool shouldShowGrowPlan(Plant plant) => plant.isHarvestable;

  static GrowPlan applyAnchor(
    GrowPlan plan,
    GrowAnchorType type,
    DateTime confirmedAt,
  ) {
    final next = <GrowAnchor>[];
    var replaced = false;
    for (final existing in plan.anchors) {
      if (existing.type == type) {
        next.add(GrowAnchor(type: type, confirmedAt: confirmedAt));
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) {
      next.add(GrowAnchor(type: type, confirmedAt: confirmedAt));
    }
    return plan.copyWith(anchors: next);
  }

  static List<DerivedStage> derive(GrowPlan plan, [CropProfile? profile]) {
    final crop = profile ?? CropCatalog.byId(plan.cropId);
    DateTime? cursor;
    final stages = <DerivedStage>[];
    for (final stage in crop.sequence) {
      final matching = _anchorForStage(plan, stage);
      if (matching != null) {
        stages.add(
          DerivedStage(
            stage: stage,
            expectedStart: matching.confirmedAt,
            confirmed: true,
            confirmedAt: matching.confirmedAt,
          ),
        );
        cursor = matching.confirmedAt;
      } else {
        final offset = crop.offsetDays[stage] ?? 0;
        final start = cursor?.add(Duration(days: offset));
        stages.add(
          DerivedStage(stage: stage, expectedStart: start, confirmed: false),
        );
        if (start != null) cursor = start;
      }
    }
    return stages;
  }

  static GrowStageView viewFor({
    required GrowPlan plan,
    required DateTime now,
  }) {
    final crop = CropCatalog.byId(plan.cropId);
    if (plan.status == GrowPlanStatus.completed) {
      return const GrowStageView(
        label: 'Season complete',
        confirmed: true,
        nextLabel: 'This grow plan is finished.',
        currentStage: GrowStage.completed,
      );
    }

    final derived = derive(plan, crop);
    DerivedStage? lastConfirmed;
    var lastConfirmedIndex = -1;
    for (var i = 0; i < derived.length; i++) {
      if (derived[i].confirmed) {
        lastConfirmed = derived[i];
        lastConfirmedIndex = i;
      }
    }
    DerivedStage? nextUnconfirmed;
    if (lastConfirmedIndex >= 0 && lastConfirmedIndex + 1 < derived.length) {
      nextUnconfirmed = derived[lastConfirmedIndex + 1];
    }

    final confirms = nextConfirmations(plan);
    if (lastConfirmed == null) {
      return GrowStageView(
        label: 'No stage confirmed yet',
        confirmed: false,
        nextLabel: 'Start by confirming sowing or a sprout.',
        nextConfirmations: confirms,
      );
    }

    if (nextUnconfirmed != null && nextUnconfirmed.expectedStart != null) {
      final expected = nextUnconfirmed.expectedStart!;
      final today = DateTime(now.year, now.month, now.day);
      final expDay = DateTime(expected.year, expected.month, expected.day);
      final daysUntil = expDay.difference(today).inDays;
      if (daysUntil > 0 && daysUntil <= 7) {
        return GrowStageView(
          label: 'Likely ${nextUnconfirmed.stage.likelySoonLabel} soon',
          confirmed: false,
          currentStage: lastConfirmed.stage,
          nextLabel: _nextAround(nextUnconfirmed, expected),
          nextConfirmations: confirms,
        );
      }
      if (!expDay.isAfter(today)) {
        return GrowStageView(
          label: lastConfirmed.stage.confirmedLabel,
          confirmed: true,
          currentStage: lastConfirmed.stage,
          nextLabel: _nextAround(nextUnconfirmed, expected),
          nextConfirmations: confirms,
        );
      }
      return GrowStageView(
        label: lastConfirmed.stage.confirmedLabel,
        confirmed: true,
        currentStage: lastConfirmed.stage,
        nextLabel: _nextAround(nextUnconfirmed, expected),
        nextConfirmations: confirms,
      );
    }

    return GrowStageView(
      label: lastConfirmed.stage.confirmedLabel,
      confirmed: true,
      currentStage: lastConfirmed.stage,
      nextLabel: crop.harvestRepeat == HarvestRepeat.repeated
          ? 'Record harvest when you’re ready.'
          : 'Mark the season complete when you’re done.',
      nextConfirmations: confirms,
    );
  }

  static List<GrowAnchorType> nextConfirmations(
    GrowPlan plan, {
    int limit = 2,
  }) {
    if (plan.status == GrowPlanStatus.completed) return const [];
    final crop = CropCatalog.byId(plan.cropId);
    final out = <GrowAnchorType>[];
    for (final type in crop.anchors) {
      if (type == GrowAnchorType.firstHarvest) continue;
      if (plan.anchor(type) != null) continue;
      out.add(type);
      if (out.length >= limit) break;
    }
    return out;
  }

  static List<GrowDueAction> dueActions({
    required DateTime now,
    required List<Plant> plants,
    required List<GrowPlan> plans,
    List<HarvestRecord> harvests = const [],
  }) {
    final byId = <String, Plant>{for (final plant in plants) plant.id: plant};
    final actions = <GrowDueAction>[];
    for (final plan in plans) {
      final plant = byId[plan.plantId];
      if (plant == null) continue;
      final action = dueAction(
        now: now,
        plant: plant,
        plan: plan,
        harvests: harvests.where((h) => h.plantId == plan.plantId).toList(),
      );
      if (action != null) actions.add(action);
    }
    actions.sort((a, b) => a.sortTime.compareTo(b.sortTime));
    return actions;
  }

  static GrowDueAction? dueAction({
    required DateTime now,
    required Plant plant,
    required GrowPlan plan,
    List<HarvestRecord> harvests = const [],
  }) {
    if (!plant.isHarvestable) return null;
    if (plant.id != plan.plantId) return null;
    if (plan.status != GrowPlanStatus.active) return null;

    final crop = CropCatalog.byId(plan.cropId);
    final derived = derive(plan, crop);
    final today = DateTime(now.year, now.month, now.day);

    if (crop.anchors.contains(GrowAnchorType.transplanted) &&
        plan.anchor(GrowAnchorType.transplanted) == null &&
        plan.anchor(GrowAnchorType.germinated) != null) {
      final vegetative = _stage(derived, GrowStage.vegetative);
      final start = vegetative?.expectedStart;
      if (start != null && !_afterDay(start, today)) {
        return GrowDueAction(
          id: 'grow-transplant-${plan.id}',
          plantId: plant.id,
          title: 'Transplant ${plant.name}',
          subtitle: 'Seedling stage is ready for the next step.',
          sortTime: start,
        );
      }
    }

    final harvestStage = _stage(derived, GrowStage.harvestReady);
    final harvestStart = harvestStage?.expectedStart;
    if (harvestStart == null || _afterDay(harvestStart, today)) return null;
    if (!_harvestCardAllowed(harvests, now)) return null;

    return GrowDueAction(
      id: 'grow-harvest-${plan.id}',
      plantId: plant.id,
      title: 'Check for Harvest',
      subtitle: 'Your expected harvest window has started.',
      sortTime: harvestStart,
    );
  }

  static PlantEvent milestoneEvent({
    required String plantId,
    required GrowAnchorType type,
    required DateTime now,
  }) {
    return PlantEvent(
      id: Plant.generateDurableId(),
      plantId: plantId,
      eventType: PlantEventType.milestone,
      timestamp: now,
      payload: {
        'title': type.milestoneTitle,
        'kind': 'grow_anchor',
        'anchor': type.wireName,
      },
      source: 'grow',
    );
  }

  static PlantEvent harvestEvent({
    required HarvestRecord harvest,
    required bool firstHarvest,
  }) {
    return PlantEvent(
      id: Plant.generateDurableId(),
      plantId: harvest.plantId,
      eventType: PlantEventType.harvest,
      timestamp: harvest.timestamp,
      payload: {
        'harvestId': harvest.id,
        'growPlanId': harvest.growPlanId,
        if (harvest.quantity != null) 'quantity': harvest.quantity,
        if (harvest.unit != null) 'unit': harvest.unit,
        if (harvest.note != null) 'note': harvest.note,
        if (harvest.photoPath != null) 'photoPath': harvest.photoPath,
        'firstHarvest': firstHarvest,
      },
      source: 'grow',
    );
  }

  static PlantEvent planCompletedEvent({
    required String plantId,
    required DateTime now,
  }) {
    return PlantEvent(
      id: Plant.generateDurableId(),
      plantId: plantId,
      eventType: PlantEventType.milestone,
      timestamp: now,
      payload: {'title': 'Grow plan completed', 'kind': 'grow_completed'},
      source: 'grow',
    );
  }

  static GrowAnchor? _anchorForStage(GrowPlan plan, GrowStage stage) {
    for (final anchor in plan.anchors) {
      if (anchor.type.confirmedStage == stage) return anchor;
    }
    return null;
  }

  static DerivedStage? _stage(List<DerivedStage> stages, GrowStage stage) {
    for (final item in stages) {
      if (item.stage == stage) return item;
    }
    return null;
  }

  static bool _afterDay(DateTime value, DateTime day) {
    final valueDay = DateTime(value.year, value.month, value.day);
    return valueDay.isAfter(day);
  }

  static bool _harvestCardAllowed(List<HarvestRecord> harvests, DateTime now) {
    DateTime? latest;
    for (final harvest in harvests) {
      if (latest == null || harvest.timestamp.isAfter(latest)) {
        latest = harvest.timestamp;
      }
    }
    if (latest == null) return true;
    return now.difference(latest) >= harvestNagCooldown;
  }

  static String _nextAround(DerivedStage stage, DateTime expected) {
    final month = expected.month;
    final day = expected.day;
    final label = stage.stage == GrowStage.harvestReady
        ? 'harvest window'
        : stage.stage == GrowStage.vegetative
        ? 'transplant'
        : stage.stage.confirmedLabel.toLowerCase();
    return 'Next: $label around $month/$day.';
  }
}
