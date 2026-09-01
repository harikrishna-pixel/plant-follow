import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantidentifier/ads/interstitial_scan_manager.dart';
import 'package:plantidentifier/services/wallet_service.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/review.dart';
import 'package:plantidentifier/view/screens/purchase_paywall/paywall.dart';
import 'package:plantidentifier/view/screens/result_screen.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../provider/plant_provider.dart';
import '../../mixpanel/mixpanel.dart';
import '../../services/picked_media.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  static const String _bonusScanFlagKey = 'has_claimed_bonus_scan';
  XFile? _image;
  bool _loading = false;
  late ScaffoldMessengerState _scaffoldMessenger;
  bool _isSubscribed = false;
  int _freeScansRemaining = 3;
  bool _bonusScanClaimed = false;
  bool _isWalletSyncing = false;

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
    // Track Scan Screen view
    MixpanelService.trackScanScreen();

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

    InterstitialScanManager.instance.warmUp();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scaffoldMessenger = ScaffoldMessenger.of(context);
      await _checkInternetOnEnter();
      await _checkSubscriptionStatus();
      await _loadFreeScans();
    });
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// Load free scans count from SharedPreferences
  Future<void> _loadFreeScans() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _freeScansRemaining = prefs.getInt('free_scans_remaining') ?? 3;
      _bonusScanClaimed = prefs.getBool(_bonusScanFlagKey) ?? false;
    });
    await _syncWalletFromCloud();
  }

  /// Save free scans count to SharedPreferences
  Future<void> _saveFreeScan({bool syncRemote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('free_scans_remaining', _freeScansRemaining);
    if (!syncRemote) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await WalletService.instance.setAvailableScans(
          user.uid,
          _freeScansRemaining,
        );
      } catch (e) {
        debugPrint('Failed to sync scans to wallet: $e');
      }
    }
  }

  Future<void> _saveBonusScanFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bonusScanFlagKey, _bonusScanClaimed);
  }

  Future<void> _syncWalletFromCloud({bool forceServer = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isWalletSyncing && !forceServer) return;

    if (mounted) {
      setState(() {
        _isWalletSyncing = true;
      });
    } else {
      _isWalletSyncing = true;
    }

    try {
      final wallet = forceServer
          ? await WalletService.instance.forceRefreshWallet(user.uid)
          : await WalletService.instance.ensureUserWallet(user);

      if (!mounted) {
        _freeScansRemaining = wallet.availableScans;
        _isWalletSyncing = false;
        return;
      }

      setState(() {
        _freeScansRemaining = wallet.availableScans;
        _isWalletSyncing = false;
      });

      await _saveFreeScan(syncRemote: false);
    } catch (e) {
      debugPrint('Failed to sync wallet: $e');
    } finally {
      if (mounted && _isWalletSyncing) {
        setState(() {
          _isWalletSyncing = false;
        });
      } else {
        _isWalletSyncing = false;
      }
    }
  }

  Future<void> _offerExtraScanAd() async {
    if (_bonusScanClaimed || !mounted) return;

    final granted = await InterstitialScanManager.instance.showExtraScanAd();
    if (!mounted) return;

    if (granted) {
      setState(() {
        _bonusScanClaimed = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await WalletService.instance.grantAdReward(user.uid);
        await _syncWalletFromCloud(forceServer: true);
        await _saveFreeScan(syncRemote: false);
      } else {
        setState(() {
          _freeScansRemaining = 1;
        });
        await _saveFreeScan();
      }

      await _saveBonusScanFlag();
      Fluttertoast.showToast(
        msg: "🎉 Bonus scan unlocked!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.green,
      );
    } else {
      Fluttertoast.showToast(
        msg: "Ad not ready. Please try again soon.",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.orange,
      );
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      setState(() {
        _isSubscribed = customerInfo.entitlements.active.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      setState(() {
        _isSubscribed = false;
      });
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('https://www.google.com/favicon.ico'))
          .then((req) => req.close())
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkInternetOnEnter() async {
    if (!mounted) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showNoInternetSnackBar();
      return;
    }

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      _showNoInternetSnackBar();
    }
  }

  void _showNoInternetSnackBar() {
    if (!mounted) return;
    _scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text(
          '❌ You are offline. Please connect to the Internet and try again.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Check if user has free scans or subscription
    if (!_isSubscribed && _freeScansRemaining <= 0) {
      Fluttertoast.showToast(
        msg: "Free scans used! Please subscribe to continue.",
        toastLength: Toast.LENGTH_LONG,
      );
      Get.to(() => const PayWallScreen());
      return;
    }

    if (!mounted) return;

    try {
      final picked = await PickedMedia.pickPlantPhoto(source: source);
      if (!mounted || picked == null) return;
      setState(() => _image = picked);
      await _identifyPlant();
    } catch (e) {
      debugPrint('Scan image pick failed: $e');
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: "Couldn't use that photo. Try another one.",
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _identifyPlant() async {
    if (_image == null) return;
    if (!mounted) return;
    if (!File(_image!.path).existsSync()) {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("That photo couldn't be opened. Try uploading again."),
        ),
      );
      return;
    }

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      _showNoInternetSnackBar();
      return;
    }

    setState(() => _loading = true);

    // Start animations
    _scanLineController.repeat();
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _particleController.repeat();

    final result = await Provider.of<PlantProvider>(
      context,
      listen: false,
    ).identifyPlant(File(_image!.path));

    if (!mounted) return;

    // Stop animations
    _scanLineController.stop();
    _pulseController.stop();
    _rotationController.stop();
    _particleController.stop();

    setState(() => _loading = false);

    if (result != null) {
      // Mark that user has performed a scan (for Share App popup timing)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_performed_scan', true);

      // Deduct free scan only if not subscribed
      if (!_isSubscribed && _freeScansRemaining > 0) {
        int scansAfterUse = _freeScansRemaining;
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          try {
            await WalletService.instance.consumeScan(user.uid);
            await _syncWalletFromCloud(forceServer: true);
            scansAfterUse = _freeScansRemaining;
            await _saveFreeScan(syncRemote: false);
          } catch (e) {
            debugPrint('Failed to consume wallet scan: $e');
            setState(() {
              _freeScansRemaining = (_freeScansRemaining > 0)
                  ? _freeScansRemaining - 1
                  : 0;
            });
            scansAfterUse = _freeScansRemaining;
            await _saveFreeScan(syncRemote: false);
          }
        } else {
          setState(() {
            _freeScansRemaining = (_freeScansRemaining > 0)
                ? _freeScansRemaining - 1
                : 0;
          });
          scansAfterUse = _freeScansRemaining;
          await _saveFreeScan(syncRemote: false);
        }

        if (scansAfterUse > 0) {
          Fluttertoast.showToast(
            msg: "✅ $scansAfterUse free scans remaining",
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.green,
          );
        } else {
          Fluttertoast.showToast(
            msg: "Last free scan used! Subscribe for unlimited scans.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.orange,
          );
        }

        // Only show interstitial ad if user is not subscribed
        if (scansAfterUse == 0 && !_isSubscribed) {
          await _offerExtraScanAd();
        }
      }

      // In ScanScreen, around line 270-275, update this section:

      // Show Rate Us popup only once for new users
      // final prefs = await SharedPreferences.getInstance();
      final hasSeenRatePopup =
          prefs.getBool('has_seen_rate_popup') ?? false; // Changed key name

      if (!hasSeenRatePopup && mounted) {
        await _showRateUsPopup();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(plant: result)),
      );
    } else {
      if (!mounted) return;
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Could not identify the plant. Try another photo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(
          'Scan Plant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: _loading
                ? _buildScanningAnimation()
                : _isSubscribed || _freeScansRemaining > 0
                ? _buildScanButtons()
                : _buildSubscribePrompt(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return AnimatedBuilder(
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
                          if (_image != null)
                            Image.file(
                              File(_image!.path),
                              fit: BoxFit.cover,
                              width: 220,
                              height: 220,
                            )
                          else
                            const Center(
                              child: Icon(
                                Icons.local_florist,
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
                                ((_particleController.value + (index * 0.125)) %
                                        1.0) *
                                    30;
                            final x = 110 + radius * cos(angle);
                            final y = 110 + radius * sin(angle);
                            final opacity =
                                1.0 -
                                ((_particleController.value + (index * 0.125)) %
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
                    Icons.eco,
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
                  'Analyzing Plant',
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
                    final opacity = ((_particleController.value + delay) % 1.0);
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
                  'Identifying species and characteristics...',
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
    );
  }

  Widget _buildScanButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _image == null
                ? const Icon(
                    Icons.local_florist,
                    size: 80,
                    color: Color(0xFF4CAF50),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(_image!.path), fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(height: 40),

          // Show free trial badge
          if (!_isSubscribed && _freeScansRemaining > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Enjoy Your $_freeScansRemaining Free Scans',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2E7D32),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          _buildScanButton(
            Icons.photo_camera,
            'Take Photo',
            () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 8),
          _buildScanButton(
            Icons.photo_library,
            'Gallery',
            () => _pickImage(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribePrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          'Free scans used!',
          style: GoogleFonts.poppins(
            color: Colors.grey[800],
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Subscribe to get unlimited plant scans',
          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Get.to(() => const PayWallScreen()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Subscribe Now',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF4CAF50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
      ),
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
                    // In the Maybe Later button onPressed (around line 870):
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
