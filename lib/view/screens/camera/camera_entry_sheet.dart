import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../navigation/v1_nav.dart';
import '../diagnosis/plant_diagnosis_screen.dart';
import '../scan_screen.dart';

Widget cameraScreenFor(CameraEntryMode mode) {
  switch (mode) {
    case CameraEntryMode.identify:
      return const ScanScreen();
    case CameraEntryMode.diagnose:
      return const PlantDiagnosisScreen();
  }
}

Future<CameraEntryMode?> showCameraEntrySheet(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(CameraEntryRoutes.lastModePrefsKey);
  final last = raw == null ? null : CameraEntryRoutes.fromWire(raw);
  if (!context.mounted) return null;

  final selected = await showModalBottomSheet<CameraEntryMode>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => CameraEntrySheet(lastUsed: last),
  );

  if (selected != null) {
    await prefs.setString(
      CameraEntryRoutes.lastModePrefsKey,
      CameraEntryRoutes.wireName(selected),
    );
  }
  return selected;
}

class CameraEntrySheet extends StatelessWidget {
  final CameraEntryMode? lastUsed;

  const CameraEntrySheet({super.key, this.lastUsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Camera',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose what you want to do.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              _ModeRow(
                icon: Icons.search_rounded,
                title: 'Identify',
                subtitle: 'What plant is this?',
                recentlyUsed: lastUsed == CameraEntryMode.identify,
                onTap: () =>
                    Navigator.pop(context, CameraEntryMode.identify),
              ),
              const SizedBox(height: 12),
              _ModeRow(
                icon: Icons.eco_outlined,
                title: 'Diagnose',
                subtitle: 'Something looks off — get a closer look.',
                recentlyUsed: lastUsed == CameraEntryMode.diagnose,
                onTap: () =>
                    Navigator.pop(context, CameraEntryMode.diagnose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool recentlyUsed;
  final VoidCallback onTap;

  const _ModeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.recentlyUsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FDF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.22),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF2E7D32), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      if (recentlyUsed) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Last used',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
