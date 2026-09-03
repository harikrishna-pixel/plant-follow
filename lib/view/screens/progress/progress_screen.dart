import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/recovery_models.dart';
import '../../../navigation/v1_nav.dart';
import '../../../provider/plant_provider.dart';
import '../../../provider/recovery_provider.dart';
import '../../../services/plant_local.dart';
import '../../../services/plant_timeline.dart';
import '../../../services/progress_logic.dart';
import '../../../widgets/pf_components.dart';
import '../camera/camera_entry_sheet.dart';
import '../favourite_screen/favourite_details.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recovery = context.watch<RecoveryProvider>();
    final plants = context.watch<PlantProvider>().favorites;
    final snapshot = ProgressLogic.from(
      cases: recovery.cases,
      outcomes: recovery.outcomes,
      events: LocalStorageService.getAllPlantEvents(),
    );
    final names = {for (final p in plants) p.id: p.name};

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          V1Nav.progressLabel,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF172019),
          ),
        ),
      ),
      body: snapshot.isEmpty
          ? _EmptyProgress(
              onIdentify: () async {
                final mode = await showCameraEntrySheet(context);
                if (mode == null) return;
                Get.to(() => cameraScreenFor(mode));
              },
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (snapshot.activeRecoveries.isNotEmpty) ...[
                  _sectionTitle('Active recoveries'),
                  const SizedBox(height: 8),
                  ...snapshot.activeRecoveries.map(
                    (c) => _ActiveRecoveryTile(
                      recoveryCase: c,
                      plantName: names[c.plantId] ?? 'Plant',
                      onTap: () => _openPlant(context, plants, c.plantId),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (snapshot.recentOutcomes.isNotEmpty) ...[
                  _sectionTitle('Recent outcomes'),
                  const SizedBox(height: 8),
                  ...snapshot.recentOutcomes.map(
                    (o) => _OutcomeTile(
                      outcome: o,
                      plantName: names[o.plantId] ?? 'Plant',
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (snapshot.recentProgress.isNotEmpty) ...[
                  _sectionTitle('Recent progress'),
                  const SizedBox(height: 8),
                  ...snapshot.recentProgress.map((e) {
                    final item = PlantTimelineMapper.fromEvent(e);
                    return _ProgressEventTile(
                      title: item.title,
                      detail: item.detail,
                      plantName: names[e.plantId] ?? '',
                    );
                  }),
                ],
              ],
            ),
    );
  }

  static void _openPlant(
    BuildContext context,
    List plants,
    String plantId,
  ) {
    for (final plant in plants) {
      if (plant.id == plantId) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FavoriteDetailScreen(plant: plant),
          ),
        );
        return;
      }
    }
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  final VoidCallback onIdentify;

  const _EmptyProgress({required this.onIdentify});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: PfEmptyState(
        icon: Icons.show_chart,
        title: ProgressSnapshot.emptyTitle,
        subtitle: ProgressSnapshot.emptySubtitle,
        actionLabel: ProgressSnapshot.identifyCta,
        onAction: onIdentify,
      ),
    );
  }
}

class _ActiveRecoveryTile extends StatelessWidget {
  final RecoveryCase recoveryCase;
  final String plantName;
  final VoidCallback onTap;

  const _ActiveRecoveryTile({
    required this.recoveryCase,
    required this.plantName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.12)),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          plantName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          recoveryCase.day3CompletedAt == null
              ? 'Waiting for Day 3 check-back'
              : 'Waiting for Day 7 check-back',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  final RecoveryOutcome outcome;
  final String plantName;

  const _OutcomeTile({required this.outcome, required this.plantName});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        plantName,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        outcome.result.label,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
      ),
    );
  }
}

class _ProgressEventTile extends StatelessWidget {
  final String title;
  final String detail;
  final String plantName;

  const _ProgressEventTile({
    required this.title,
    required this.detail,
    required this.plantName,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        plantName.isEmpty ? title : '$plantName · $title',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        detail,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
      ),
    );
  }
}
