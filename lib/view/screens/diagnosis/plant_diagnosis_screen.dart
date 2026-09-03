import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/gemini_service.dart';
import '../../../services/picked_media.dart';
import '../../../model/data_model/plant_model.dart';
import '../../../model/data_model/recovery_models.dart';
import '../../../provider/recovery_provider.dart';
import 'package:provider/provider.dart';
import '../../../mixpanel/mixpanel.dart';
import '../privacy_and_terms/review.dart';
import 'diagnosis_result_screen.dart';

class PlantDiagnosisScreen extends StatefulWidget {
  final Plant? plant;

  const PlantDiagnosisScreen({super.key, this.plant});

  @override
  State<PlantDiagnosisScreen> createState() => _PlantDiagnosisScreenState();
}

class _PlantDiagnosisScreenState extends State<PlantDiagnosisScreen>
    with TickerProviderStateMixin {
  bool _isAnalyzing = false;
  XFile? _selectedImage;

  // Animation controllers
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    // Track Diagnosis Screen view
    MixpanelService.trackDiagnosisScreen();

    // Initialize animation controllers
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check internet connection
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        Get.snackbar(
          "❌ ",
          "You're offline. Please connect to the Internet and try again",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final hasInternet = await _hasInternet();
      if (!hasInternet) {
        Get.snackbar(
          "❌ ",
          "You're offline. Please connect to the Internet and try again",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final XFile? image = await PickedMedia.pickPlantPhoto(source: source);

      if (image != null) {
        setState(() {
          _isAnalyzing = true;
          _selectedImage = image;
        });

        // Start animations
        _scanLineController.repeat();
        _pulseController.repeat(reverse: true);
        _rotationController.repeat();
        _particleController.repeat();

        if (!File(image.path).existsSync()) {
          throw StateError('Selected image was empty');
        }

        final attempt = await GeminiService.diagnosePlantHealth(
          File(image.path),
          plant: widget.plant,
        );

        // Stop animations
        _scanLineController.stop();
        _pulseController.stop();
        _rotationController.stop();
        _particleController.stop();

        setState(() => _isAnalyzing = false);

        if (attempt.isSuccess && attempt.json != null && mounted) {
          final diagnosisResult = attempt.json!;
          final recovery = context.read<RecoveryProvider>();
          final existingPlant = widget.plant;
          PlantDiagnosis? diagnosis;
          TreatmentPlan? treatment;
          if (existingPlant != null) {
            diagnosis = await recovery.tryPersistDiagnosisFromGemini(
              geminiJson: diagnosisResult,
              plant: existingPlant,
              photoPath: image.path,
            );
            if (diagnosis != null) {
              treatment = recovery.draftTreatment(
                geminiJson: diagnosisResult,
                diagnosis: diagnosis,
              );
            }
          }
          if (diagnosis == null && existingPlant != null) {
            if (!mounted) return;
            _showCalmFailure(
              "We couldn't check this photo",
              'Try a clearer photo of the plant, flower, or affected area.',
            );
            return;
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiagnosisResultScreen(
                imageFile: File(image.path),
                diagnosisData: diagnosisResult,
                plant: existingPlant,
                diagnosis: diagnosis,
                treatment: treatment,
              ),
            ),
          );
        } else {
          _showCalmFailure(
            "We couldn't check this photo",
            'Try a clearer photo of the plant, flower, or affected area.',
          );
        }
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showCalmFailure(
        "We couldn't check this photo",
        'Try a clearer photo of the plant, flower, or affected area.',
      );
    }
  }

  void _showCalmFailure(String title, String body) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                        child: Text(
                          'Choose Another Photo',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (_selectedImage != null) {
                            _pickImage(ImageSource.camera);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        child: Text(
                          'Try Again',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRateUsPopup() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 48,
                    color: Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Enjoying PlantFollow?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'Your feedback helps us grow! Please take a moment to rate our app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Rate Now Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Mark as seen before closing
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(
                        'has_seen_rate_popup',
                        true,
                      ); // Changed key name

                      Navigator.pop(context);
                      await RateApp.rateApp();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Rate Now',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Maybe Later Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () async {
                      // Mark as seen before closing
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(
                        'has_seen_rate_popup',
                        true,
                      ); // Changed key name

                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Maybe Later',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Image Source',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
              ),
              title: Text(
                'Camera',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF4CAF50),
                ),
              ),
              title: Text(
                'Gallery',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        title: Text(
          "What's wrong?",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF172019),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isAnalyzing
          ? _buildScanningAnimation()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Plant Health Check',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    widget.plant == null
                        ? 'Take a photo of the affected area — a leaf, flower, fruit, or the whole plant.'
                        : 'Get close to the part of ${widget.plant!.name} that looks off — leaf, flower, or whole plant.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Features
                  _buildFeatureItem(
                    Icons.bug_report_rounded,
                    'Pest Detection',
                    'Identify common pests affecting your plant',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.coronavirus_rounded,
                    'A closer look',
                    'What we noticed on the affected area',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.medical_services_rounded,
                    'What to do next',
                    'A gentle first step, then a simple plan',
                  ),
                  const SizedBox(height: 40),

                  // Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showImageSourceDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        'Start Diagnosis',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScanningAnimation() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scanLineController,
          _pulseController,
          _rotationController,
          _particleController,
        ]),
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Main scanning container with image
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulsing circles
                  ...List.generate(3, (index) {
                    final delay = index * 0.3;
                    final opacity = ((_particleController.value + delay) % 1.0);
                    return Transform.scale(
                      scale: 1.0 + (opacity * 0.5),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF4CAF50,
                            ).withOpacity(0.3 - (opacity * 0.3)),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Rotating gradient border
                  Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            const Color(0xFF4CAF50).withOpacity(0.0),
                            const Color(0xFF4CAF50).withOpacity(0.8),
                            const Color(0xFF66BB6A).withOpacity(0.8),
                            const Color(0xFF4CAF50).withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Main image container with pulse effect
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Image
                            if (_selectedImage != null)
                              Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                                width: 220,
                                height: 220,
                              )
                            else
                              const Center(
                                child: Icon(
                                  Icons.health_and_safety_rounded,
                                  size: 80,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),

                            // Scanning line overlay
                            Positioned(
                              top: _scanLineAnimation.value * 220 - 40,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF4CAF50).withOpacity(0.0),
                                      const Color(0xFF4CAF50).withOpacity(0.5),
                                      const Color(0xFF66BB6A).withOpacity(0.5),
                                      const Color(0xFF4CAF50).withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Grid overlay
                            CustomPaint(
                              size: const Size(220, 220),
                              painter: _ScanGridPainter(
                                progress: _scanLineAnimation.value,
                              ),
                            ),

                            // Scanning particles
                            ...List.generate(8, (index) {
                              final angle = (index / 8) * 2 * 3.14159;
                              final radius =
                                  80 +
                                  ((_particleController.value +
                                              (index * 0.125)) %
                                          1.0) *
                                      30;
                              final x = 110 + radius * cos(angle);
                              final y = 110 + radius * sin(angle);
                              final opacity =
                                  1.0 -
                                  ((_particleController.value +
                                          (index * 0.125)) %
                                      1.0);

                              return Positioned(
                                left: x - 3,
                                top: y - 3,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(opacity * 0.8),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(opacity * 0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Corner brackets
                  ...List.generate(4, (index) {
                    final angle = (index * 90.0) * 3.14159 / 180;
                    return Transform.rotate(
                      angle: angle,
                      child: Transform.translate(
                        offset: const Offset(100, -100),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: const Color(0xFF4CAF50).withOpacity(0.8),
                                width: 3,
                              ),
                              right: BorderSide(
                                color: const Color(0xFF4CAF50).withOpacity(0.8),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 40),

              // Animated progress indicator
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: null,
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    ),
                    Icon(
                      Icons.health_and_safety_rounded,
                      color: const Color(0xFF4CAF50).withOpacity(0.8),
                      size: 24,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Animated text
              Column(
                children: [
                  Text(
                    'Analyzing Plant Health',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final delay = index * 0.3;
                      final opacity =
                          ((_particleController.value + delay) % 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(opacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detecting issues and providing care tips...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4CAF50), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for scanning grid overlay
class _ScanGridPainter extends CustomPainter {
  final double progress;

  _ScanGridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal lines
    for (int i = 0; i <= 10; i++) {
      final y = (size.height / 10) * i;
      final isActive = (progress * 10).floor() == i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isActive ? activePaint : paint,
      );
    }

    // Draw vertical lines
    for (int i = 0; i <= 10; i++) {
      final x = (size.width / 10) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw corner markers
    final cornerPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final cornerSize = 20.0;

    // Top-left
    canvas.drawLine(Offset(0, 0), Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(Offset(0, 0), Offset(0, cornerSize), cornerPaint);

    // Top-right
    canvas.drawLine(
      Offset(size.width - cornerSize, 0),
      Offset(size.width, 0),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerSize),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height - cornerSize),
      Offset(0, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerSize, size.height),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - cornerSize, size.height),
      Offset(size.width, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - cornerSize),
      Offset(size.width, size.height),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(_ScanGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
