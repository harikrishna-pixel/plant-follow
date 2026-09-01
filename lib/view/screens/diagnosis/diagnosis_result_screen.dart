import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/plant_model.dart';
import '../../../model/data_model/recovery_models.dart';
import '../../../provider/plant_provider.dart';
import '../../../provider/recovery_provider.dart';
import 'recovery_checkin_screen.dart';

class DiagnosisResultScreen extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> diagnosisData;
  final Plant? plant;
  final PlantDiagnosis? diagnosis;
  final TreatmentPlan? treatment;

  const DiagnosisResultScreen({
    super.key,
    required this.imageFile,
    required this.diagnosisData,
    this.plant,
    this.diagnosis,
    this.treatment,
  });

  @override
  State<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends State<DiagnosisResultScreen> {
  late TreatmentPlan? _treatment;
  PlantDiagnosis? _diagnosis;
  Plant? _plant;
  RecoveryCase? _case;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _treatment = widget.treatment;
    _diagnosis = widget.diagnosis;
    _plant = widget.plant;
    if (_plant != null) {
      _case = context.read<RecoveryProvider>().activeCaseForPlant(_plant!.id);
    }
  }

  Color _conditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'looking okay':
      case 'healthy':
        return const Color(0xFF4CAF50);
      case 'struggling':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFFF9A825);
    }
  }

  Future<void> _startRecovery() async {
    final recovery = context.read<RecoveryProvider>();
    setState(() => _starting = true);
    try {
      var plant = _plant;
      var diagnosis = _diagnosis;
      var treatment = _treatment;
      if (plant == null) {
        plant = Plant(
          name: widget.diagnosisData['plant_name'] as String? ?? 'Unknown plant',
          scientificName: '',
          description: '',
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
          imagePath: widget.imageFile.path,
        );
        await context.read<PlantProvider>().saveFavorite(plant);
      }
      diagnosis ??= await recovery.persistDiagnosisFromGemini(
        geminiJson: widget.diagnosisData,
        plant: plant,
        photoPath: widget.imageFile.path,
      );
      treatment ??= recovery.draftTreatment(
        geminiJson: widget.diagnosisData,
        diagnosis: diagnosis,
      );
      final opened = await recovery.startRecovery(
        plant: plant,
        diagnosis: diagnosis,
        treatment: treatment,
      );
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _diagnosis = diagnosis;
        _treatment = recovery.treatmentById(opened.treatmentId) ?? treatment;
        _case = opened;
        _starting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(recovery.checkBackSentence(opened)),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
    }
  }

  Future<void> _toggleStep(TreatmentStep step) async {
    final treatment = _treatment;
    if (treatment == null || treatment.recoveryCaseId == null) return;
    await context.read<RecoveryProvider>().completeTreatmentStep(
          treatment: treatment,
          stepId: step.id,
        );
    setState(() {
      _treatment = context.read<RecoveryProvider>().treatmentById(treatment.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = _diagnosis;
    final plantName = diagnosis?.plantName.isNotEmpty == true
        ? diagnosis!.plantName
        : (widget.diagnosisData['plant_name'] ?? 'Plant');
    final condition = diagnosis?.overallCondition.isNotEmpty == true
        ? diagnosis!.overallCondition
        : 'needs attention';
    final confidence = diagnosis?.confidence.wireName ?? 'medium';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      appBar: AppBar(
        title: Text(
          'What we noticed',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 250,
              child: Image.file(widget.imageFile, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plantName.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _chip(condition, _conditionColor(condition)),
                      const SizedBox(width: 8),
                      _chip('Confidence: $confidence', Colors.grey.shade700),
                    ],
                  ),
                  if (_case != null) ...[
                    const SizedBox(height: 16),
                    _checkBackCard(context),
                  ],
                  const SizedBox(height: 24),
                  if (diagnosis != null) ..._diagnosisBlocks(diagnosis),
                  if (diagnosis == null) _legacyFallback(),
                  if (_treatment != null) ..._treatmentBlocks(),
                  const SizedBox(height: 12),
                  if (_case == null)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _starting ? null : _startRecovery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _starting ? 'Starting…' : 'Start recovery plan',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    _openCaseActions(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _checkBackCard(BuildContext context) {
    final recovery = context.read<RecoveryProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        recovery.checkBackSentence(_case!),
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1B5E20),
        ),
      ),
    );
  }

  List<Widget> _diagnosisBlocks(PlantDiagnosis diagnosis) {
    return [
      _sectionTitle('Likely issue'),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diagnosis.primaryIssue.name,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
            if (diagnosis.primaryIssue.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                diagnosis.primaryIssue.explanation,
                style: GoogleFonts.inter(height: 1.5, color: Colors.grey[800]),
              ),
            ],
            if (diagnosis.primaryIssue.evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Affected area: ${diagnosis.primaryIssue.evidence}',
                style: GoogleFonts.inter(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
      if (diagnosis.confidence == DiagnosisConfidence.medium &&
          diagnosis.alternativeIssue != null &&
          !diagnosis.alternativeIssue!.isEmpty) ...[
        _sectionTitle('Another possibility'),
        _card(
          child: Text(
            '${diagnosis.alternativeIssue!.name}. ${diagnosis.alternativeIssue!.explanation}',
            style: GoogleFonts.inter(height: 1.5, color: Colors.grey[800]),
          ),
        ),
      ],
      if (diagnosis.confidence == DiagnosisConfidence.low) ...[
        _sectionTitle('Two likely explanations'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. ${diagnosis.primaryIssue.name}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              if (diagnosis.secondExplanation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '2. ${diagnosis.secondExplanation!.name}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'A check-back will help tell these apart. We will not pretend certainty.',
                style: GoogleFonts.inter(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
      _sectionTitle('One safe thing you can do now'),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diagnosis.firstAid.action,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
            if (diagnosis.firstAid.method.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                diagnosis.firstAid.method,
                style: GoogleFonts.inter(height: 1.5, color: Colors.grey[800]),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _treatmentBlocks() {
    final steps = _treatment!.steps;
    return [
      _sectionTitle('What to do next'),
      ...steps.map((step) {
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF4CAF50),
                    child: Text(
                      '${step.order}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  if (_case != null)
                    IconButton(
                      onPressed: step.isCompleted
                          ? null
                          : () => _toggleStep(step),
                      icon: Icon(
                        step.isCompleted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                ],
              ),
              if (step.timing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    step.timing,
                    style: GoogleFonts.inter(color: Colors.grey[700]),
                  ),
                ),
              if (step.method.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    step.method,
                    style: GoogleFonts.inter(height: 1.5, color: Colors.grey[800]),
                  ),
                ),
              if (step.rationale.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    step.rationale,
                    style: GoogleFonts.inter(color: Colors.grey[600], height: 1.4),
                  ),
                ),
              if (step.isIrreversible)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Please pause before this step: ${step.irreversibleWarning}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    ];
  }

  Widget _legacyFallback() {
    final noticed = widget.diagnosisData['what_we_noticed'] ??
        widget.diagnosisData['description'] ??
        '';
    return _card(
      child: Text(
        noticed.toString().isEmpty
            ? 'We looked at the photo and prepared a gentle next step.'
            : noticed.toString(),
        style: GoogleFonts.inter(height: 1.5),
      ),
    );
  }

  Widget _openCaseActions(BuildContext context) {
    final recovery = context.read<RecoveryProvider>();
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecoveryCheckInScreen(
                    recoveryCase: _case!,
                    plant: _plant!,
                    stage: _case!.day3CompletedAt == null
                        ? CheckInStage.day3
                        : CheckInStage.day7,
                  ),
                ),
              );
            },
            child: Text(
              'Open check-in',
              style: GoogleFonts.poppins(color: const Color(0xFF2E7D32)),
            ),
          ),
        ),
        TextButton(
          onPressed: () => recovery.deferTreatment(_case!),
          child: Text(
            "I haven't got to it yet",
            style: GoogleFonts.inter(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
