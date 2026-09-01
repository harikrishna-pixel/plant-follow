import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/grow_plan.dart';
import '../../../model/data_model/plant_model.dart';
import '../../../provider/grow_plan_provider.dart';
import '../../../provider/plant_provider.dart';
import '../../../services/grow_logic.dart';

class PlantGrowCard extends StatelessWidget {
  final Plant plant;

  const PlantGrowCard({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    if (!GrowLogic.shouldShowGrowPlan(plant)) {
      return const SizedBox.shrink();
    }

    return Consumer<GrowPlanProvider>(
      builder: (context, grow, _) {
        final plan = grow.planForPlant(plant.id);
        if (plan == null) {
          return _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow plan',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirm a stage to start a plan for this plant.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip(
                      context,
                      GrowAnchorType.sowed.confirmLabel,
                      () => grow.confirmAnchor(
                        plant: plant,
                        type: GrowAnchorType.sowed,
                      ),
                    ),
                    _chip(
                      context,
                      GrowAnchorType.germinated.confirmLabel,
                      () => grow.confirmAnchor(
                        plant: plant,
                        type: GrowAnchorType.germinated,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final view = GrowLogic.viewFor(plan: plan, now: DateTime.now());
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grow plan',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                view.label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                view.nextLabel,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
              ),
              if (view.nextConfirmations.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in view.nextConfirmations)
                      _chip(
                        context,
                        type.confirmLabel,
                        () => grow.confirmAnchor(plant: plant, type: type),
                      ),
                  ],
                ),
              ],
              if (plan.status == GrowPlanStatus.active) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _recordHarvest(context, plant),
                      child: Text(
                        'Record harvest',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => grow.completePlan(plant),
                      child: Text(
                        'Season is done',
                        style: GoogleFonts.inter(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.12)),
      ),
      child: child,
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: const Color(0xFFE8F5E9),
    );
  }

  Future<void> _recordHarvest(BuildContext context, Plant plant) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    String unit = 'count';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Record harvest', style: GoogleFonts.poppins()),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity (optional)',
                    ),
                  ),
                  DropdownButton<String>(
                    value: unit,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'count', child: Text('Count')),
                      DropdownMenuItem(value: 'g', child: Text('Grams')),
                      DropdownMenuItem(value: 'kg', child: Text('Kilograms')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => unit = value);
                    },
                  ),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final raw = quantityController.text.trim();
    await context.read<GrowPlanProvider>().recordHarvest(
      plant: plant,
      quantity: raw.isEmpty ? null : double.tryParse(raw),
      unit: raw.isEmpty ? null : unit,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );
  }
}

class HarvestablePlantControl extends StatelessWidget {
  final Plant plant;

  const HarvestablePlantControl({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlantProvider, GrowPlanProvider>(
      builder: (context, plants, grow, _) {
        Plant live = plant;
        for (final candidate in plants.favorites) {
          if (candidate.id == plant.id) {
            live = candidate;
            break;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Grown for harvest',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              subtitle: Text(
                'Adds a grow plan for this plant only.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              value: live.isHarvestable,
              activeThumbColor: const Color(0xFF2E7D32),
              onChanged: (value) async {
                final cropId = value
                    ? (live.cropId ?? CropCatalog.genericId)
                    : live.cropId;
                await plants.updatePlant(
                  live.copyWith(isHarvestable: value, cropId: cropId),
                );
                if (value) {
                  await grow.ensurePlan(
                    live.copyWith(isHarvestable: true, cropId: cropId),
                  );
                }
              },
            ),
            if (live.isHarvestable) ...[
              Text(
                'Crop type',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final profile in CropCatalog.all)
                    ChoiceChip(
                      label: Text(
                        profile.label,
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      selected:
                          (live.cropId ?? CropCatalog.genericId) == profile.id,
                      selectedColor: const Color(0xFFC8E6C9),
                      onSelected: (_) async {
                        await plants.updatePlant(
                          live.copyWith(cropId: profile.id),
                        );
                        await grow.setCrop(
                          live.copyWith(
                            cropId: profile.id,
                            isHarvestable: true,
                          ),
                          profile.id,
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
