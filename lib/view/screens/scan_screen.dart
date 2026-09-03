import 'dart:io';
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
import '../../services/identification_analytics.dart';
import '../../services/identification_policy.dart';
import '../../services/identification_result.dart';
import '../../services/identify_logic.dart';
import '../../widgets/pf_components.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  static const String _bonusScanFlagKey = 'has_claimed_bonus_scan';
  XFile? _image;
  bool _loading = false;
  final IdentifyRequestGuard _identifyGuard = IdentifyRequestGuard();
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

  @override
  void initState() {
    super.initState();
    MixpanelService.trackScanScreen();

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
          "We couldn't connect. Check your connection and try again.",
        ),
        backgroundColor: Color(0xFF5D6D57),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_loading || _identifyGuard.isInFlight) return;
    // Identification is unlimited. Legacy wallet/quota is not a gate.
    if (!IdentificationPolicy.canStartIdentification(
      isSubscribed: _isSubscribed,
      freeScansRemaining: _freeScansRemaining,
    )) {
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
    if (!_identifyGuard.tryStart()) return;
    IdentificationAnalytics.started();
    if (!File(_image!.path).existsSync()) {
      _identifyGuard.finish();
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("That photo couldn't be opened. Try uploading again."),
        ),
      );
      return;
    }

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      _identifyGuard.finish();
      _showNoInternetSnackBar();
      return;
    }

    setState(() => _loading = true);

    // Start animations
    _scanLineController.repeat();
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _particleController.repeat();

    IdentifyAttempt attempt;
    try {
      attempt = await Provider.of<PlantProvider>(
        context,
        listen: false,
      ).identifyPlant(File(_image!.path));
    } catch (_) {
      attempt = IdentifyAttempt.fail(IdentifyFailureKind.api);
    }

    _identifyGuard.finish();
    if (!mounted) return;

    // Stop animations
    _scanLineController.stop();
    _pulseController.stop();
    _rotationController.stop();
    _particleController.stop();

    setState(() => _loading = false);

    final result = attempt.plant;
    if (attempt.isSuccess && result != null) {
      if (attempt.result != null && attempt.result!.identificationUncertain) {
        IdentificationAnalytics.uncertain(attempt.result!);
      } else if (attempt.result != null) {
        IdentificationAnalytics.succeeded(attempt.result!);
      }
      // Mark that user has performed a scan (for Share App popup timing)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_performed_scan', true);

      // Legacy wallet consume/remaining toasts are dormant on Identify.
      // WalletService remains for referrals and historical balances.

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
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            plant: result,
            identification: attempt.result,
          ),
        ),
      );
    } else {
      IdentificationAnalytics.failed(attempt.failure?.name ?? 'unknown');
      if (!mounted) return;
      _showIdentifyFailure(attempt.failure);
    }
  }

  void _showIdentifyFailure(IdentifyFailureKind? kind) {
    final tips = IdentificationResult.retryTipsFor(ImageQualityKind.unknown)
        .take(IdentificationResult.maxRetryTips)
        .toList();
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
                  IdentifyFailureCopy.title(kind),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  IdentifyFailureCopy.body(kind),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                if (kind == IdentifyFailureKind.invalid ||
                    kind == IdentifyFailureKind.parser) ...[
                  const SizedBox(height: 12),
                  ...tips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $tip',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    child: Text(
                      IdentifyLogic.retryAction,
                      style: GoogleFonts.poppins(
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        title: Text(
          'Identify Plant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading ? _buildScanningAnimation() : _buildScanButtons(),
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return PfLoadingBlock(
      title: 'Analyzing plant',
      subtitle: 'Looking at leaf shape and details…',
      photo: _image == null
          ? null
          : Image.file(File(_image!.path), fit: BoxFit.cover),
    );
  }
  Widget _buildScanButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E9E2)),
            ),
            child: _image == null
                ? const Icon(
                    Icons.local_florist_outlined,
                    size: 56,
                    color: Color(0xFF1F6F35),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(_image!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 280,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            'Take a clear photo of the plant',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF172019),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Include leaves, stem and surrounding details.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF667068),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take Photo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
          ),
          const Spacer(),
        ],
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
