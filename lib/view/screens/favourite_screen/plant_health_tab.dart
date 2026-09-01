import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/plant_model.dart';
import '../../../model/data_model/recovery_models.dart';
import '../../../provider/recovery_provider.dart';
import '../../../services/plant_health_presenter.dart';
import '../../../services/recovery_store.dart';
import '../diagnosis/plant_diagnosis_screen.dart';
import '../diagnosis/recovery_checkin_screen.dart';

class PlantHealthTab extends StatelessWidget {
  final Plant plant;

  const PlantHealthTab({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final recovery = context.watch<RecoveryProvider>();
    final active = recovery.activeCaseForPlant(plant.id);
    final outcomes = recovery.outcomesForPlant(plant.id);
    final diagnosis = active != null
        ? recovery.diagnosisById(active.diagnosisId)
        : _latestDiagnosis(plant.id);
    final treatment = active == null
        ? null
        : recovery.treatmentById(active.treatmentId);
    final view = PlantHealthPresenter.fromState(
      now: DateTime.now(),
      activeCase: active,
      diagnosis: diagnosis,
      treatment: treatment,
      outcomes: outcomes,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (view.hasActiveRecovery && active != null)
          _activeCard(context, active, view)
        else
          _emptyCard(context, view),
        if (!view.hasActiveRecovery && view.issueName != null) ...[
          const SizedBox(height: 12),
          _noteCard('Last diagnosis', view.issueName!),
        ],
        if (!view.hasActiveRecovery && view.latestOutcome != null) ...[
          const SizedBox(height: 12),
          _noteCard('Last outcome', view.latestOutcome!.label),
        ],
      ],
    );
  }

  Widget _emptyCard(BuildContext context, PlantHealthView view) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(
            view.headline,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            view.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlantDiagnosisScreen(plant: plant),
                ),
              );
            },
            child: Text(
              "Something's wrong",
              style: GoogleFonts.poppins(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(
    BuildContext context,
    RecoveryCase active,
    PlantHealthView view,
  ) {
    final due = view.nextCheckInLabel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            view.headline,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          if (view.confidenceLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              view.confidenceLabel!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            view.body,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
          ),
          if (view.stageLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              view.stageLabel!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
          if (view.treatmentTotal > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Treatment ${view.treatmentDone} of ${view.treatmentTotal} steps done.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecoveryCheckInScreen(
                    recoveryCase: active,
                    plant: plant,
                    stage: active.day3CompletedAt == null
                        ? CheckInStage.day3
                        : CheckInStage.day7,
                  ),
                ),
              );
            },
            child: Text(
              due == null ? 'Continue recovery' : 'Continue $due check-in',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  PlantDiagnosis? _latestDiagnosis(String plantId) {
    final list = RecoveryStore.diagnosesForPlant(plantId);
    return list.isEmpty ? null : list.first;
  }
}
