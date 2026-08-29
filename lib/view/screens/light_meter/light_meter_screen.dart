import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:plantidentifier/utils/constants.dart';

class LightMeterScreen extends StatefulWidget {
  const LightMeterScreen({super.key});

  @override
  State<LightMeterScreen> createState() => _LightMeterScreenState();
}

class _LightMeterScreenState extends State<LightMeterScreen> with SingleTickerProviderStateMixin {
  String get _endpoint => AppConstants.geminiGenerateContentEndpoint;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Timer? _scanTimer;
  double _currentLux = 0;
  String _lightLevel = 'Ready to scan';
  String _recommendation = '';
  bool _isScanning = false;
  bool _isAnalyzing = false;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _startScanning() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not initialized. Please restart the app.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _recommendation = '';
    });

    // Capture and analyze brightness every 1 second
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!_isScanning) {
        timer.cancel();
        return;
      }
      if (!_isCapturing) {
        await _captureAndAnalyzeBrightness();
      }
    });
  }

  Future<void> _captureAndAnalyzeBrightness() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) {
      return;
    }

    _isCapturing = true;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage != null) {
        // Calculate average brightness
        int totalBrightness = 0;
        int pixelCount = 0;

        for (int y = 0; y < decodedImage.height; y += 10) {
          for (int x = 0; x < decodedImage.width; x += 10) {
            final pixel = decodedImage.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            totalBrightness += ((r + g + b) / 3).round();
            pixelCount++;
          }
        }

        final avgBrightness = totalBrightness / pixelCount;
        
        // Convert brightness (0-255) to approximate lux
        // This is a rough approximation
        final estimatedLux = _brightnessToLux(avgBrightness);

        if (mounted) {
          setState(() {
            _currentLux = estimatedLux;
            _lightLevel = _getLightLevel(estimatedLux);
          });
        }
      }

      // Clean up the temporary file
      await File(image.path).delete();
    } catch (e) {
      debugPrint('Error analyzing brightness: $e');
    } finally {
      _isCapturing = false;
    }
  }

  double _brightnessToLux(double brightness) {
    // Convert brightness (0-255) to lux (0-50000)
    // This is an approximation based on typical indoor/outdoor values
    if (brightness < 30) return 10;
    if (brightness < 60) return 50;
    if (brightness < 90) return 150;
    if (brightness < 120) return 300;
    if (brightness < 150) return 600;
    if (brightness < 180) return 1500;
    if (brightness < 210) return 5000;
    if (brightness < 240) return 15000;
    return 30000;
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  String _getLightLevel(double lux) {
    if (lux < 50) return 'Very Low Light';
    if (lux < 200) return 'Low Light';
    if (lux < 500) return 'Medium Light';
    if (lux < 1000) return 'Bright Light';
    if (lux < 10000) return 'Very Bright Light';
    return 'Direct Sunlight';
  }

  String _getEnvironmentType(double lux) {
    if (lux < 200) return 'Deep Indoor / Shaded Area';
    if (lux < 500) return 'Indoor / Away from Windows';
    if (lux < 1000) return 'Indoor / Near Windows';
    if (lux < 10000) return 'Bright Indoor / Partial Outdoor';
    return 'Full Outdoor / Direct Sunlight';
  }

  Future<void> _analyzeLight() async {
    if (_currentLux == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan the light first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final prompt = '''
You are a plant care expert. Based on the following light measurement:
- Light Intensity: ${_currentLux.toStringAsFixed(0)} lux
- Light Level: $_lightLevel
- Environment: ${_getEnvironmentType(_currentLux)}

Provide a detailed analysis including:
1. What types of plants thrive in this light condition
2. Specific plant recommendations (at least 5 plants)
3. Care tips for plants in this lighting
4. Whether this is suitable for indoor or outdoor plants
5. Any warnings or considerations

Keep the response concise but informative.
''';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text'];
        // Remove asterisks and clean up formatting
        final cleanedReply = _cleanMarkdown(reply);
        setState(() {
          _recommendation = cleanedReply;
        });
      } else {
        // Show red snackbar for error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Check your internet connection',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        setState(() {
          _recommendation = 'Check your internet connection';
        });
      }
    } catch (e) {
      // Show red snackbar for internet connection error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Check your internet connection',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      setState(() {
        _recommendation = 'Check your internet connection';
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  /// Clean markdown formatting from Gemini response
  String _cleanMarkdown(String text) {
    // Remove asterisks (**, *, etc.)
    String cleaned = text.replaceAll(RegExp(r'\*+'), '');
    
    // Remove other common markdown symbols
    cleaned = cleaned.replaceAll(RegExp(r'#+\s'), ''); // Remove headers
    cleaned = cleaned.replaceAll(RegExp(r'`+'), ''); // Remove code blocks
    cleaned = cleaned.replaceAll(RegExp(r'_+'), ''); // Remove underscores
    
    // Clean up multiple spaces and newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Max 2 newlines
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' '); // Remove multiple spaces
    
    return cleaned.trim();
  }

  Color _getLightColor(double lux) {
    if (lux < 50) return const Color(0xFF1E3A8A);
    if (lux < 200) return const Color(0xFF3B82F6);
    if (lux < 500) return const Color(0xFF10B981);
    if (lux < 1000) return const Color(0xFFFBBF24);
    if (lux < 10000) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  IconData _getLightIcon(double lux) {
    if (lux < 200) return Icons.nightlight_round;
    if (lux < 500) return Icons.wb_twilight;
    if (lux < 1000) return Icons.wb_cloudy;
    if (lux < 10000) return Icons.wb_sunny;
    return Icons.light_mode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Light Meter',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Light Meter Display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    _getLightColor(_currentLux).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _getLightColor(_currentLux).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Animated Light Icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isScanning ? _pulseAnimation.value : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getLightColor(_currentLux),
                                _getLightColor(_currentLux).withOpacity(0.7),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _getLightColor(_currentLux).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getLightIcon(_currentLux),
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Lux Value
                  Text(
                    '${_currentLux.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: _getLightColor(_currentLux),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'lux',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Light Level
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _getLightColor(_currentLux).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getLightColor(_currentLux).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _lightLevel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getLightColor(_currentLux),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Environment Type
                  Text(
                    _getEnvironmentType(_currentLux),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? _stopScanning : _startScanning,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning ? Colors.red : const Color(0xFFFBBF24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(
                        _isScanning ? Icons.stop : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isScanning ? 'Stop Scanning' : 'Start Scanning',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF11998E).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeLight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.psychology, color: Colors.white),
                      label: Text(
                        'Analyze',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Light Guide
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Light Level Guide',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLightGuideItem('0-50 lux', 'Very Low', 'Deep shade, night', const Color(0xFF1E3A8A)),
                  _buildLightGuideItem('50-200 lux', 'Low', 'Indoor, away from windows', const Color(0xFF3B82F6)),
                  _buildLightGuideItem('200-500 lux', 'Medium', 'Indoor, near windows', const Color(0xFF10B981)),
                  _buildLightGuideItem('500-1000 lux', 'Bright', 'Bright indoor/partial shade', const Color(0xFFFBBF24)),
                  _buildLightGuideItem('1000-10000 lux', 'Very Bright', 'Outdoor shade/bright indoor', const Color(0xFFF59E0B)),
                  _buildLightGuideItem('10000+ lux', 'Direct Sun', 'Full outdoor sunlight', const Color(0xFFEF4444)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // AI Recommendations
            if (_recommendation.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFF11998E).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF11998E).withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF11998E).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI Recommendations',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _recommendation,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF4B5563),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLightGuideItem(String range, String level, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      range,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        level,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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

  @override
  void dispose() {
    _scanTimer?.cancel();
    _cameraController?.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
