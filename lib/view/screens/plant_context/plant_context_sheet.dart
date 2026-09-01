import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/plant_context.dart';
import '../../../model/data_model/plant_location.dart';
import '../../../model/data_model/plant_model.dart';
import '../../../provider/location_provider.dart';
import '../../../provider/plant_provider.dart';
import '../../../services/location_store.dart';

/// Short post-save / plant-detail prompt. Not a migration questionnaire.
Future<Plant?> showPlantContextSheet(
  BuildContext context, {
  required Plant plant,
}) {
  return showModalBottomSheet<Plant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PlantContextSheet(plant: plant),
  );
}

class PlantContextSheet extends StatefulWidget {
  final Plant plant;

  const PlantContextSheet({super.key, required this.plant});

  @override
  State<PlantContextSheet> createState() => _PlantContextSheetState();
}

class _PlantContextSheetState extends State<PlantContextSheet> {
  late PlantWeatherContext _placement;
  String? _locationId;
  bool _saving = false;

  static const _choices = [
    PlantWeatherContext.indoor,
    PlantWeatherContext.outdoorPotted,
    PlantWeatherContext.gardenBed,
    PlantWeatherContext.greenhouseCovered,
    PlantWeatherContext.unknown,
  ];

  @override
  void initState() {
    super.initState();
    _placement = widget.plant.placement;
    _locationId = widget.plant.locationId;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final locations = context.read<LocationProvider>();
    final plants = context.read<PlantProvider>();
    var locationId = _locationId;
    if (locationId == null || locationId.isEmpty) {
      locationId = locations.home?.id ?? LocationStore.defaultHomeId;
      if (locations.byId(locationId) == null) {
        await locations.load();
        locationId = locations.home?.id;
      }
    }
    final updated = widget.plant.copyWith(
      placement: _placement,
      locationId: locationId,
    );
    await plants.updatePlant(updated);
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<LocationProvider>().locations;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where does this one live?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.plant.name,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in _choices)
                ChoiceChip(
                  label: Text(
                    choice == PlantWeatherContext.unknown
                        ? 'Not sure yet'
                        : choice.label,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  selected: _placement == choice,
                  selectedColor: const Color(0xFFC8E6C9),
                  onSelected: (_) => setState(() => _placement = choice),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Place',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 6),
          if (locations.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _dropdownValue(locations),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FDF8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final location in locations)
                DropdownMenuItem(
                  value: location.id,
                  child: Text(location.name),
                ),
            ],
              onChanged: (value) => setState(() => _locationId = value),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _saving ? 'Saving…' : 'Save',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(
              'Skip for now',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String? _dropdownValue(List<PlantLocation> locations) {
    if (locations.isEmpty) return null;
    if (_locationId != null &&
        locations.any((l) => l.id == _locationId)) {
      return _locationId;
    }
    return locations.first.id;
  }
}
