import 'package:flutter/material.dart';

import '../model/data_model/grow_plan.dart';
import '../model/data_model/plant_model.dart';
import '../services/grow_logic.dart';
import '../services/grow_plan_store.dart';
import '../services/plant_local.dart';

class GrowPlanProvider extends ChangeNotifier {
  List<GrowPlan> _plans = [];
  List<HarvestRecord> _harvests = [];

  List<GrowPlan> get plans => List.unmodifiable(_plans);
  List<HarvestRecord> get harvests => List.unmodifiable(_harvests);

  GrowPlanProvider() {
    load();
  }

  Future<void> load() async {
    _plans = GrowPlanStore.all();
    _harvests = HarvestStore.all();
    notifyListeners();
  }

  GrowPlan? planForPlant(String plantId) {
    for (final plan in _plans) {
      if (plan.plantId == plantId) return plan;
    }
    return GrowPlanStore.forPlant(plantId);
  }

  List<HarvestRecord> harvestsForPlant(String plantId) {
    return _harvests.where((h) => h.plantId == plantId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<GrowPlan> ensurePlan(Plant plant, {DateTime? now}) async {
    final existing = planForPlant(plant.id);
    if (existing != null) return existing;
    final crop = CropCatalog.byId(plant.cropId);
    final plan = GrowPlan(
      id: Plant.generateDurableId(),
      plantId: plant.id,
      cropId: crop.id,
      createdAt: now ?? DateTime.now(),
      harvestRepeat: crop.harvestRepeat,
      locationId: plant.locationId,
    );
    await GrowPlanStore.save(plan);
    await load();
    return planForPlant(plant.id) ?? plan;
  }

  Future<GrowPlan> confirmAnchor({
    required Plant plant,
    required GrowAnchorType type,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    var plan = await ensurePlan(plant, now: at);
    plan = GrowLogic.applyAnchor(plan, type, at);
    await GrowPlanStore.save(plan);
    await LocalStorageService.appendPlantEvent(
      GrowLogic.milestoneEvent(plantId: plant.id, type: type, now: at),
    );
    await load();
    return planForPlant(plant.id) ?? plan;
  }

  Future<HarvestRecord> recordHarvest({
    required Plant plant,
    DateTime? now,
    double? quantity,
    String? unit,
    String? note,
    String? photoPath,
  }) async {
    final at = now ?? DateTime.now();
    final plan = await ensurePlan(plant, now: at);
    final previous = harvestsForPlant(plant.id);
    final first = previous.isEmpty;
    final harvest = HarvestRecord(
      id: Plant.generateDurableId(),
      plantId: plant.id,
      growPlanId: plan.id,
      timestamp: at,
      quantity: quantity,
      unit: unit,
      note: note,
      photoPath: photoPath,
    );
    await HarvestStore.save(harvest);
    await LocalStorageService.appendPlantEvent(
      GrowLogic.harvestEvent(harvest: harvest, firstHarvest: first),
    );
    if (first) {
      final withAnchor = GrowLogic.applyAnchor(
        plan,
        GrowAnchorType.firstHarvest,
        at,
      );
      await GrowPlanStore.save(withAnchor);
      await LocalStorageService.appendPlantEvent(
        GrowLogic.milestoneEvent(
          plantId: plant.id,
          type: GrowAnchorType.firstHarvest,
          now: at,
        ),
      );
    }
    await load();
    return harvest;
  }

  Future<GrowPlan> completePlan(Plant plant, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final plan = await ensurePlan(plant, now: at);
    final updated = plan.copyWith(
      status: GrowPlanStatus.completed,
      completedAt: at,
    );
    await GrowPlanStore.save(updated);
    await LocalStorageService.appendPlantEvent(
      GrowLogic.planCompletedEvent(plantId: plant.id, now: at),
    );
    await load();
    return planForPlant(plant.id) ?? updated;
  }

  Future<GrowPlan> setCrop(Plant plant, String cropId) async {
    final crop = CropCatalog.byId(cropId);
    final plan = await ensurePlan(plant);
    final updated = plan.copyWith(
      cropId: crop.id,
      harvestRepeat: crop.harvestRepeat,
    );
    await GrowPlanStore.save(updated);
    await load();
    return planForPlant(plant.id) ?? updated;
  }
}
