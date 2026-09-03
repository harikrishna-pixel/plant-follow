import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/plant_model.dart';
import '../../../model/data_model/recovery_models.dart';
import '../../../provider/recovery_provider.dart';
import '../../../services/phase3_smoke_seed.dart';
import '../../../services/picked_media.dart';

class RecoveryCheckInScreen extends StatefulWidget {
  final RecoveryCase recoveryCase;
  final Plant plant;
  final CheckInStage stage;

  const RecoveryCheckInScreen({
    super.key,
    required this.recoveryCase,
    required this.plant,
    required this.stage,
  });

  @override
  State<RecoveryCheckInScreen> createState() => _RecoveryCheckInScreenState();
}

class _RecoveryCheckInScreenState extends State<RecoveryCheckInScreen> {
  final _noteController = TextEditingController();
  String? _newPhotoPath;
  CheckInAssessment? _assessment;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await PickedMedia.pickPlantPhoto(source: ImageSource.camera);
      if (file != null) {
        setState(() => _newPhotoPath = file.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't use that photo. Try again.")),
      );
    }
  }

  Future<void> _submit() async {
    if (_newPhotoPath == null || _assessment == null) return;
    setState(() => _saving = true);
    final recovery = context.read<RecoveryProvider>();
    final updated = await recovery.recordCheckIn(
      recoveryCase: widget.recoveryCase,
      stage: widget.stage,
      assessment: _assessment!,
      photoPath: _newPhotoPath!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final message = updated.status.isClosed
        ? 'Recorded as ${updated.status.wireName.replaceAll('_', ' ')}.'
        : recovery.checkBackSentence(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.recoveryCase.originalPhotoPath;
    final isDay3 = widget.stage == CheckInStage.day3;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isDay3 ? 'Day 3 check-in' : 'Day 7 check-in',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'How is ${widget.plant.name} looking?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compare it with the first photo.',
            style: GoogleFonts.inter(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _photoTile('First photo', original, null)),
              const SizedBox(width: 12),
              Expanded(
                child: _photoTile('New photo', _newPhotoPath, _pickPhoto),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Compared with before, it is:',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final option in CheckInAssessment.values)
            RadioListTile<CheckInAssessment>(
              value: option,
              groupValue: _assessment,
              onChanged: (value) => setState(() => _assessment = value),
              title: Text(option.label, style: GoogleFonts.inter()),
              activeColor: const Color(0xFF2E7D32),
            ),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Optional note',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (Phase3SmokeSeed.enabled)
            TextButton(
              onPressed: () {
                final path = Phase3SmokeSeed.samplePhotoPath;
                if (path == null || path.isEmpty) return;
                setState(() => _newPhotoPath = path);
              },
              child: Text(
                'Use sample photo',
                style: GoogleFonts.inter(color: const Color(0xFF2E7D32)),
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving || _newPhotoPath == null || _assessment == null
                  ? null
                  : _submit,
              child: Text(_saving ? 'Saving…' : 'Save Check-in'),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<RecoveryProvider>().deferTreatment(
                widget.recoveryCase,
              );
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Text(
              "I haven't got to it yet",
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          if (!isDay3)
            TextButton(
              onPressed: () => _confirmLost(context),
              child: Text(
                'This plant did not make it',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Future<void> _confirmLost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remember this plant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'We can close this recovery and keep the history. Nothing here is a failure — plants sometimes do not pull through.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close as lost'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<RecoveryProvider>().closeCase(
      recoveryCase: widget.recoveryCase,
      result: OutcomeResult.lost,
      closeReason: 'user_closed_lost',
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _photoTile(String label, String? path, VoidCallback? onTap) {
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: hasFile
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFE8F5E8),
                      child: Icon(
                        onTap == null ? Icons.image : Icons.add_a_photo,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12)),
        ],
      ),
    );
  }
}
