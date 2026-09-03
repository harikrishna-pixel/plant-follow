import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plantidentifier/services/weather_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:plantidentifier/services/wallet_service.dart';
import 'package:plantidentifier/services/auth_service.dart';
import 'package:plantidentifier/services/plant_local.dart';
import 'package:plantidentifier/model/data_model/user_wallet.dart';
import 'package:plantidentifier/view/screens/auth/login_screen.dart';
import 'package:plantidentifier/view/screens/purchase_paywall/paywall.dart';
import 'package:plantidentifier/view/screens/scan_screen.dart';
import 'package:plantidentifier/view/screens/weather/weather_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import 'package:http/http.dart' as http;
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/model/data_model/plant_location.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/provider/plant_provider.dart';
import 'package:plantidentifier/provider/recovery_provider.dart';
import 'package:plantidentifier/provider/reminder_provider.dart';
import 'package:plantidentifier/provider/care_rule_provider.dart';
import 'package:plantidentifier/provider/location_provider.dart';
import 'package:plantidentifier/provider/grow_plan_provider.dart';
import 'package:plantidentifier/services/care_completion.dart';
import 'package:plantidentifier/services/care_context_resolver.dart';
import 'package:plantidentifier/services/care_weather_analytics.dart';
import 'package:plantidentifier/services/grow_logic.dart';
import 'package:plantidentifier/services/location_weather_cache.dart';
import 'package:plantidentifier/services/today_priority.dart';
import 'package:plantidentifier/services/weather_snapshot.dart';
import 'package:plantidentifier/view/screens/diagnosis/recovery_checkin_screen.dart';
import 'package:plantidentifier/view/screens/today/today_feed.dart';
import 'privacy_and_terms/faq.dart';
import 'favourite_screen/favourite_details.dart';
import 'package:plantidentifier/mixpanel/mixpanel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSubscribed = false;
  CustomerInfo? _customerInfo;

  // Weather state
  WeatherData? _weatherData;
  bool _isWeatherLoading = true;
  final WeatherService _weatherService = WeatherService();
  bool _referralPromptChecked = false;
  bool _referralDialogVisible = false;
  bool _locationPermissionChecked = false;
  DateTime? _lastUserRefresh;
  bool _isOpeningPaywall = false;
  late final LocationWeatherLookup _locationWeatherLookup;
  bool _prefetchingWeather = false;

  @override
  void initState() {
    super.initState();
    // Track Dashboard Screen view
    MixpanelService.trackDashboardScreen();
    _locationWeatherLookup = LocationWeatherLookup(_weatherService);
    _checkSubscriptionStatus();
    // Don't load weather immediately - wait for referral dialog to complete
    _checkFirstTime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptReferral();
    });

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      setState(() {
        _customerInfo = customerInfo;
        _isSubscribed = customerInfo.entitlements.active.isNotEmpty;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user data when screen becomes visible again (e.g., returning from Account screen)
    // Debounce to avoid excessive reloads (only reload if last refresh was more than 1 second ago)
    final now = DateTime.now();
    if (_lastUserRefresh == null ||
        now.difference(_lastUserRefresh!).inSeconds > 1) {
      _lastUserRefresh = now;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshUserData();
        // Check weather state when returning to screen - reload if stuck in loading or no data
        if (_isWeatherLoading && _weatherData == null) {
          _loadWeather();
        } else if (!_isWeatherLoading && _weatherData == null) {
          // If not loading but no data, try to reload
          _loadWeather();
        }
      });
    }
  }

  Future<void> _refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        if (mounted) {
          setState(() {
            // Trigger rebuild to update name display
          });
        }
      } catch (e) {
        debugPrint('Failed to reload user data: $e');
      }
    }
  }

  /// Check if it's the first time opening the app
  Future<void> _checkFirstTime() async {
    // Don't show welcome dialog here - it will be shown after referral and location popups
    // This method is kept for future use if needed
  }

  /// Show beautiful welcome dialog with share-to-unlock feature
  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WelcomeDialog(),
    );
  }

  Future<void> _maybePromptReferral() async {
    if (_referralPromptChecked || !mounted) return;
    _referralPromptChecked = true;

    final user = FirebaseAuth.instance.currentUser;
    // Only show referral dialog if user is signed in (not null and not anonymous)
    // Referral code should only appear after proper sign in, not for anonymous users or after purchase without sign in
    if (user == null || user.isAnonymous) {
      // For unsigned users, still check and show welcome dialog if applicable
      _checkAndRequestLocationPermission();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final promptKey = 'referral_prompt_shown_${user.uid}';
    final alreadyShown = prefs.getBool(promptKey) ?? false;
    if (alreadyShown) return;

    try {
      final wallet = await WalletService.instance.ensureUserWallet(user);
      if (!mounted) return;

      if (wallet.referred || wallet.referredBy != null) {
        await prefs.setBool(promptKey, true);
        // Still check location permission even if referral already applied
        // Then show welcome dialog after location permission
        _checkAndRequestLocationPermission();
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        await _showReferralDialog(wallet, prefs, promptKey);
        // After referral dialog is dismissed, check location permission
        if (mounted) {
          _checkAndRequestLocationPermission();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to evaluate referral prompt: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _showReferralDialog(
    UserWallet wallet,
    SharedPreferences prefs,
    String promptKey,
  ) async {
    if (_referralDialogVisible) return;
    _referralDialogVisible = true;
    String referralInput = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Claim Your Referral Bonus',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'If a friend invited you, enter their referral ID to unlock extra scans.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]'),
                        ),
                        LengthLimitingTextInputFormatter(8),
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        final normalized = value.toUpperCase();
                        if (normalized != referralInput) {
                          setStateDialog(() {
                            referralInput = normalized;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Referral ID',
                        counterText: '',
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1FAF3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your referral ID to share',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            wallet.referralCode,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          await prefs.setBool(promptKey, true);
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = referralInput.trim().toUpperCase();
                          if (code.isEmpty) {
                            setStateDialog(() {
                              errorText = 'Enter your friend\'s referral ID';
                            });
                            return;
                          }
                          if (code == wallet.referralCode) {
                            setStateDialog(() {
                              errorText =
                                  'Use the code shared by your friend, not your own.';
                            });
                            return;
                          }

                          setStateDialog(() {
                            errorText = null;
                            isSubmitting = true;
                          });

                          try {
                            final applied = await WalletService.instance
                                .applyReferralCode(
                                  referredUid: wallet.uid,
                                  referralCode: code,
                                );
                            if (!mounted) return;

                            if (applied) {
                              await prefs.setBool(promptKey, true);
                              await WalletService.instance.forceRefreshWallet(
                                wallet.uid,
                              );
                              Navigator.of(dialogContext).pop();
                              Fluttertoast.showToast(
                                msg:
                                    'Referral bonus unlocked! +2 scans have been added.',
                                toastLength: Toast.LENGTH_LONG,
                                timeInSecForIosWeb: 4,
                                backgroundColor: const Color(0xFF388E3C),
                              );
                            } else {
                              setStateDialog(() {
                                isSubmitting = false;
                                errorText =
                                    'That referral ID is invalid or already used.';
                              });
                            }
                          } catch (e) {
                            setStateDialog(() {
                              isSubmitting = false;
                              errorText =
                                  'Unable to apply the referral right now. Try again later.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Apply',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
    _referralDialogVisible = false;
  }

  /// Check and request location permission after referral dialog
  Future<void> _checkAndRequestLocationPermission() async {
    if (_locationPermissionChecked || !mounted) return;
    _locationPermissionChecked = true;

    // Wait a moment before checking location
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Now load weather which will request location permission if needed
    _loadWeather();

    // After location permission, show welcome share popup with delay
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      _checkAndShowWelcomeDialog();
    }
  }

  /// Check and show welcome dialog after referral and location popups
  Future<void> _checkAndShowWelcomeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('first_time_home') ?? true;
    final hasScanned = prefs.getBool('has_performed_scan') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    final isSignedIn = user != null && !user.isAnonymous;

    // Show welcome/share dialog if:
    // 1. First time AND has scanned (existing logic), OR
    // 2. User is not signed in OR not subscribed (show for unsigned/unsubscribed users)
    final shouldShowForUnsigned = !isSignedIn || !_isSubscribed;

    if (isFirstTime && mounted && (hasScanned || shouldShowForUnsigned)) {
      _showWelcomeDialog();
    }
  }

  Future<void> _clearLocalUserState(String uid) async {
    await LocalStorageService.clearAllSearchCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('free_scans_remaining');
    await prefs.remove('referral_prompt_shown_$uid');
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'Log out?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'You will need to sign in again to access your wallet and scans.',
              style: GoogleFonts.inter(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Log out',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = currentUser?.uid;
      await AuthService.instance.signOut();
      if (uid != null) {
        await _clearLocalUserState(uid);
      }

      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }

      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'You have been logged out.',
        toastLength: Toast.LENGTH_SHORT,
      );
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to log out. Please try again.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    Navigator.pop(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(
        msg: 'Please sign in again.',
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.redAccent,
      );
      Get.offAll(() => const LoginScreen());
      return;
    }

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'Delete account?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
            content: Text(
              'This will permanently delete your scans, wallet balance, referral data, and account. This action cannot be undone.',
              style: GoogleFonts.inter(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final uid = user.uid;

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Automatically re-authenticate and retry deletion
        try {
          // Check provider before re-authenticating
          final providerId = user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : null;

          if (providerId == null) {
            throw Exception('No provider found for user');
          }

          // Re-authenticate using the same provider
          await AuthService.instance.reauthenticateUser(user);

          // Retry deletion after re-authentication
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser != null) {
            await refreshedUser.delete();
          } else {
            throw Exception('User not found after re-authentication');
          }
        } catch (reauthError) {
          if (rootNavigator.canPop()) {
            rootNavigator.pop();
          }
          if (!mounted) return;

          // Show appropriate error message
          String errorMsg = 'Could not delete account. Please try again later.';
          if (reauthError.toString().contains('cancel') ||
              reauthError.toString().contains('cancelled')) {
            errorMsg =
                'Account deletion cancelled. Please sign in again to delete your account.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg, style: GoogleFonts.inter())),
          );
          return;
        }
      } else {
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete account: ${e.message ?? 'Unknown error'}',
              style: GoogleFonts.inter(),
            ),
          ),
        );
        return;
      }
    } catch (e) {
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete account. Please try again later.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      return;
    }

    try {
      await WalletService.instance.deleteUserWallet(uid);
    } catch (e, stackTrace) {
      debugPrint('Failed to delete wallet for $uid: $e');
      debugPrint('$stackTrace');
    }

    await LocalStorageService.clearAllData();
    await _clearLocalUserState(uid);

    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // Ignore sign-out errors after account deletion
    }

    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }

    if (!mounted) return;
    Fluttertoast.showToast(
      msg: 'Account deleted successfully.',
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.redAccent,
    );
    Get.offAll(() => const LoginScreen());
  }

  /// ✅ Check RevenueCat entitlements
  Future<void> _checkSubscriptionStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      setState(() {
        _customerInfo = customerInfo;
        _isSubscribed = customerInfo.entitlements.active.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Error checking subscription: $e');
    }
  }

  /// Load weather data
  Future<void> _loadWeather() async {
    try {
      final weather = await _weatherService.getCurrentWeather();
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isWeatherLoading = false;
        });
        try {
          final locations = context.read<LocationProvider>();
          final home = locations.home;
          if (home != null &&
              (home.city == null || home.city!.trim().isEmpty) &&
              weather.cityName.trim().isNotEmpty) {
            await locations.updateLocation(
              home.copyWith(city: weather.cityName),
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Weather load error: $e');
      if (mounted) {
        setState(() {
          _isWeatherLoading = false;
        });
      }
    }
  }

  void _showSubscriptionDetails() {
    if (_customerInfo == null) return;

    final entitlements = _customerInfo!.entitlements.active;
    if (entitlements.isEmpty) return;

    // Get the first active entitlement from RevenueCat
    final entitlement = entitlements.values.first;

    // Get dates directly from RevenueCat entitlement
    final expirationDate = entitlement.expirationDate;
    final originalPurchaseDate = entitlement.originalPurchaseDate;

    debugPrint('🔍 Expiration Date: $expirationDate');
    debugPrint('🔍 Original Purchase Date: $originalPurchaseDate');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Active Subscription',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re enjoying PlantFollow Pro',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Subscription Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4CAF50).withOpacity(0.1),
                    const Color(0xFF66BB6A).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  // Start Date (from RevenueCat)
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    'Started On',
                    originalPurchaseDate != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(DateTime.parse(originalPurchaseDate))
                        : 'N/A',
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300], height: 1),
                  const SizedBox(height: 16),

                  // Expiration Date
                  _buildDetailRow(
                    Icons.event_rounded,
                    'Expires On',
                    expirationDate != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(DateTime.parse(expirationDate))
                        : 'Never',
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300], height: 1),
                  const SizedBox(height: 16),

                  // Days Remaining
                  _buildDetailRow(
                    Icons.hourglass_bottom_rounded,
                    'Days Remaining',
                    expirationDate != null
                        ? _calculateDaysRemaining(expirationDate)
                        : '∞',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Check the Internet Connection //
  Future<bool> _hasInternet() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com/favicon.ico'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHighlight
                ? const Color(0xFF4CAF50)
                : const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isHighlight ? Colors.white : const Color(0xFF4CAF50),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isHighlight
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _calculateDaysRemaining(String expirationDate) {
    try {
      final expiry = DateTime.parse(expirationDate);
      final now = DateTime.now();
      final difference = expiry.difference(now).inDays;

      if (difference < 0) return 'Expired';
      if (difference == 0) return 'Expires Today';
      if (difference == 1) return '1 day';
      return '$difference days';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good Evening';
    } else {
      return 'Good Evening';
    }
  }

  TodayPriorityResult _resolveToday({
    required RecoveryProvider recovery,
    required ReminderProvider reminders,
    required PlantProvider plants,
    required CareRuleProvider careRules,
    required GrowPlanProvider growPlans,
    required LocationProvider locations,
  }) {
    final plantNames = <String, String>{
      for (final plant in plants.favorites) plant.id: plant.name,
    };
    final diagnosisSummaries = <String, String>{};
    for (final recoveryCase in recovery.cases) {
      final diagnosis = recovery.diagnosisById(recoveryCase.diagnosisId);
      final name = diagnosis?.primaryIssue.name.trim() ?? '';
      if (name.isNotEmpty) {
        diagnosisSummaries[recoveryCase.diagnosisId] = name;
      }
    }
    List<TodayMilestoneCandidate> milestones = const [];
    try {
      milestones = TodayPriorityResolver.milestonesFromEvents(
        events: LocalStorageService.getAllPlantEvents(),
        now: DateTime.now(),
        plantNames: plantNames,
      );
    } catch (_) {
      milestones = const [];
    }
    final locationsById = <String, PlantLocation>{
      for (final location in locations.locations) location.id: location,
    };
    final weatherByLocationId = <String, WeatherSnapshot>{};
    for (final plant in plants.favorites) {
      final locationId = plant.locationId;
      if (locationId == null || locationId.isEmpty) continue;
      final cached = LocationWeatherCache.instance.peek(locationId);
      if (cached != null) weatherByLocationId[locationId] = cached;
    }
    _prefetchLocationWeather(plants.favorites, locations);
    return TodayPriorityResolver.resolve(
      now: DateTime.now(),
      cases: recovery.cases,
      plantNames: plantNames,
      diagnosisSummaries: diagnosisSummaries,
      reminders: reminders.reminders,
      careRules: careRules.rules,
      weather: _weatherData == null
          ? null
          : TodayWeatherSnapshot(
              temperatureC: _weatherData!.temperature,
              description: _weatherData!.description,
            ),
      milestones: milestones,
      growActions: GrowLogic.dueActions(
        now: DateTime.now(),
        plants: plants.favorites,
        plans: growPlans.plans,
        harvests: growPlans.harvests,
      ),
      plantWeatherContexts: plants.favorites.map((plant) => plant.placement),
      plants: plants.favorites,
      locationsById: locationsById,
      weatherByLocationId: weatherByLocationId,
    );
  }

  void _prefetchLocationWeather(
    List<Plant> plants,
    LocationProvider locations,
  ) {
    if (_prefetchingWeather) return;
    final unique = <String, PlantLocation>{};
    for (final plant in plants) {
      final location = locations.forPlant(plant);
      if (location == null) continue;
      if (LocationWeatherCache.instance.peek(location.id) != null) continue;
      unique[location.id] = location;
    }
    if (unique.isEmpty) return;
    _prefetchingWeather = true;
    Future.wait(
      unique.values.map(
        (location) => LocationWeatherCache.instance.getOrFetch(
          location: location,
          loader: _locationWeatherLookup.forLocation,
        ),
      ),
    ).then((results) {
      if (results.every((item) => item == null)) {
        CareWeatherAnalytics.contextUnavailable();
      }
      if (mounted) setState(() {});
    }).whenComplete(() {
      _prefetchingWeather = false;
    });
  }

  Future<void> _onTodayAction(
    TodayAction action, {
    required RecoveryProvider recovery,
    required ReminderProvider reminders,
    required PlantProvider plants,
    required CareRuleProvider careRules,
  }) async {
    switch (action.kind) {
      case TodayActionKind.recovery:
        final plant = _plantById(plants, action.plantId);
        RecoveryCase? recoveryCase;
        for (final item in recovery.cases) {
          if (item.id == action.recoveryCaseId) {
            recoveryCase = item;
            break;
          }
        }
        if (plant == null ||
            recoveryCase == null ||
            action.checkInStage == null) {
          return;
        }
        await Get.to(
          () => RecoveryCheckInScreen(
            recoveryCase: recoveryCase!,
            plant: plant,
            stage: action.checkInStage!,
          ),
        );
        return;
      case TodayActionKind.care:
        if (action.careRuleId != null) {
          final rule = careRules.byId(action.careRuleId);
          if (rule != null) {
            Map<String, dynamic>? extraPayload;
            if (action.careContext == CareContextState.maybeHandledByRain) {
              final plant = _plantById(plants, action.plantId);
              final locations = context.read<LocationProvider>();
              final location =
                  plant == null ? null : locations.forPlant(plant);
              final weather = location == null
                  ? null
                  : LocationWeatherCache.instance.peek(location.id);
              extraPayload = CareContextResolver.rainConfirmedPayload(
                location: location,
                weather: weather,
              );
              if (plant != null) {
                CareWeatherAnalytics.rainConfirmed(
                  placement: plant.placement,
                );
              }
            }
            await CareCompletion.complete(
              rule: rule,
              careRules: careRules,
              reminders: reminders,
              extraPayload: extraPayload,
            );
            return;
          }
        }
        if (action.reminderId != null) {
          await reminders.toggleReminderCompletion(action.reminderId!);
        }
        return;
      case TodayActionKind.weather:
        await Get.to(() => const WeatherWidget());
        return;
      case TodayActionKind.milestone:
      case TodayActionKind.grow:
        final plant = _plantById(plants, action.plantId);
        if (plant != null) {
          await Get.to(() => FavoriteDetailScreen(plant: plant));
        }
        return;
    }
  }

  Future<void> _onTodaySecondaryAction(
    TodayAction action, {
    required CareRuleProvider careRules,
    required PlantProvider plants,
  }) async {
    if (action.kind != TodayActionKind.care) return;
    if (action.careContext != CareContextState.maybeHandledByRain) return;
    final rule = careRules.byId(action.careRuleId);
    if (rule == null) return;
    await careRules.rejectRainSuggestion(rule);
    final plant = _plantById(plants, action.plantId);
    if (plant != null) {
      CareWeatherAnalytics.rainRejected(placement: plant.placement);
    }
  }

  Plant? _plantById(PlantProvider plants, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final plant in plants.favorites) {
      if (plant.id == id || plant.matchesStoredId(id)) return plant;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final friendlyName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : 'Plant Lover';
    final greeting = _getTimeBasedGreeting();

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF7F9F5),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 6.h),
            // Container(
            //   padding: EdgeInsets.all(6.w),
            //   decoration: BoxDecoration(
            //     gradient: const LinearGradient(
            //       colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            //     ),
            //     borderRadius: BorderRadius.circular(8.r),
            //   ),
            //   child: Icon(Icons.eco, color: Colors.white, size: 14.sp),
            // ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                '$greeting,\n$friendlyName',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF172019),
                  fontSize: 16,
                  height: 1.25,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Weather display
          InkWell(
            onTap: () => Get.to(const WeatherWidget()),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              margin: EdgeInsets.only(right: 6.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isWeatherLoading && _weatherData == null
                  ? SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2E7D32),
                        ),
                      ),
                    )
                  : _weatherData != null
                  ? Row(
                      children: [
                        // Weather icon
                        Image.network(
                          _weatherData!.getIconUrl(),
                          width: 22.w,
                          height: 22.h,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Icon(
                              Icons.cloud,
                              size: 18.sp,
                              color: const Color(0xFF2E7D32),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.cloud,
                              size: 18.sp,
                              color: const Color(0xFF2E7D32),
                            );
                          },
                        ),
                        SizedBox(width: 4.w),
                        // Temperature
                        Text(
                          '${_weatherData!.temperature.round()}°',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Near you',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667068),
                          ),
                        ),
                      ],
                    )
                  : Icon(Icons.cloud_off, size: 18.sp, color: Colors.grey),
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 12.w, top: 6.h, bottom: 6.h),
            child: _isSubscribed
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.info, color: Colors.white, size: 18.sp),
                      onPressed: () {
                        Get.to(LocalHtmlScreen());
                      },
                    ),
                  )
                : Builder(
                    builder: (context) {
                      // Get screen width for responsive sizing
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isTablet = screenWidth > 600;

                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF172019),
                          side: const BorderSide(color: Color(0xFFE3E9E2)),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 16 : 12,
                            vertical: isTablet ? 8 : 6,
                          ),
                          minimumSize: Size(
                            isTablet ? 64 : 52,
                            isTablet ? 36 : 32,
                          ),
                        ),
                        onPressed: () async {
                          if (_isOpeningPaywall) return;
                          setState(() {
                            _isOpeningPaywall = true;
                          });
                          try {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PayWallScreen(),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isOpeningPaywall = false;
                              });
                            }
                          }
                        },
                        child: Text(
                          'Pro',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667068),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF172019),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'What needs a look right now.',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Consumer6<
                    RecoveryProvider,
                    ReminderProvider,
                    PlantProvider,
                    CareRuleProvider,
                    GrowPlanProvider,
                    LocationProvider
                  >(
                    builder:
                        (
                          context,
                          recovery,
                          reminders,
                          plants,
                          careRules,
                          growPlans,
                          locations,
                          _,
                        ) {
                          final result = _resolveToday(
                            recovery: recovery,
                            reminders: reminders,
                            plants: plants,
                            careRules: careRules,
                            growPlans: growPlans,
                            locations: locations,
                          );
                          return TodayFeed(
                            actions: result.cards,
                            onPrimaryAction: (action) => _onTodayAction(
                              action,
                              recovery: recovery,
                              reminders: reminders,
                              plants: plants,
                              careRules: careRules,
                            ),
                            onSecondaryAction: (action) =>
                                _onTodaySecondaryAction(
                              action,
                              careRules: careRules,
                              plants: plants,
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
            SizedBox(height: 100.h),
          ],
        ),
      ),
    );
  }
}

/// Stateful welcome dialog widget
class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog();

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  bool _hasShared = false;

  Future<void> _handleShare() async {
    const appStoreLink = 'https://apps.apple.com/app/id/6752886333';

    final shareMessage =
        '''
🌿 Hey, plant lover! 💚

I just found the cutest little helper for my plants and thought to share it with you! It's called Plant Identifier & Care, and honestly… it feels like having a plant expert in your pocket.

Whether you're a proud plant parent or just trying to explore gardening, this app helps you:
🌱 Instantly identify any plant!
🌱 Know exactly how to care for it!
🌱 Get gentle reminders so you never forget again
🌱 Even helps you save sick plants before it's too late!

I didn't realise how connected I could feel to my plants until I actually started understanding what they need. If you're even a little obsessed with the plants around, you've gotta check it out.

Download PlantFollow & Care - your green thumb will thank you! 💚

$appStoreLink
''';

    // Get screen size for share position origin (required for iOS, especially iPads)
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await Share.share(shareMessage, sharePositionOrigin: sharePositionOrigin);

    // Mark as shared and update UI
    setState(() {
      _hasShared = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Check if welcome bonus has been claimed before
        // The actual check happens in tryGrantWelcomeShareReward using Firestore
        // This local check is just to avoid unnecessary calls
        final prefs = await SharedPreferences.getInstance();
        final welcomeBonusClaimed =
            prefs.getBool('welcome_bonus_claimed') ?? false;

        bool granted;
        if (!welcomeBonusClaimed) {
          // First time welcome share - grant 3 scans (300 coins)
          // This method has its own check in Firestore to prevent duplicate grants
          granted = await WalletService.instance.tryGrantWelcomeShareReward(
            user.uid,
          );
          if (granted) {
            // Only set local flag if actually granted
            await prefs.setBool('welcome_bonus_claimed', true);
          }
        } else {
          // Regular share - use normal share reward logic (20 coins)
          granted = await WalletService.instance.tryGrantShareReward(user.uid);
        }

        if (granted) {
          final wallet = await WalletService.instance.forceRefreshWallet(
            user.uid,
          );
          await prefs.setInt('free_scans_remaining', wallet.availableScans);
          if (mounted) {
            String message;
            if (!welcomeBonusClaimed) {
              // Welcome bonus granted
              message = "Welcome bonus unlocked. Thanks for sharing.";
            } else {
              // Regular share reward
              final shareCoins = wallet.shareCoins;
              final coinEarningSharesToday = wallet.coinEarningSharesToday;
              final remainingSharesForCoins =
                  UserWallet.maxCoinEarningSharesPerDay -
                  coinEarningSharesToday;

              if (remainingSharesForCoins <= 0) {
                message =
                    "✅ Share recorded! You've reached today's limit (3 shares). Share again tomorrow to earn more coins!";
              } else {
                final coinsNeeded = 100 - shareCoins;
                final sharesNeeded = (coinsNeeded / 20).ceil();

                if (shareCoins >= 100) {
                  message =
                      "Reward unlocked from sharing.";
                } else {
                  message =
                      "🎁 +20 coins earned! ($shareCoins/100 coins) $remainingSharesForCoins share${remainingSharesForCoins > 1 ? 's' : ''} left today to earn coins!";
                }
              }
            }

            Fluttertoast.showToast(
              msg: message,
              toastLength: Toast.LENGTH_LONG,
              timeInSecForIosWeb: 4,
              backgroundColor: !welcomeBonusClaimed
                  ? const Color(0xFF388E3C)
                  : (wallet.coinEarningSharesToday >=
                            UserWallet.maxCoinEarningSharesPerDay
                        ? Colors.orange
                        : const Color(0xFF388E3C)),
            );
          }
        } else {
          // Welcome bonus already claimed or error
          if (!welcomeBonusClaimed) {
            Fluttertoast.showToast(
              msg: "Welcome bonus already claimed!",
              toastLength: Toast.LENGTH_SHORT,
              backgroundColor: Colors.orange,
            );
          } else {
            Fluttertoast.showToast(
              msg: "Unable to process share reward. Please try again.",
              toastLength: Toast.LENGTH_LONG,
              timeInSecForIosWeb: 4,
              backgroundColor: Colors.orange,
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to apply share reward: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w),
        constraints: BoxConstraints(maxWidth: 420.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF5), Color(0xFFF0F9F4), Color(0xFFE8F5E9)],
          ),
          borderRadius: BorderRadius.circular(32.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Animated decorative circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4CAF50).withOpacity(0.1),
                      const Color(0xFF66BB6A).withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.08),
                      const Color(0xFF4CAF50).withOpacity(0.04),
                    ],
                  ),
                ),
              ),
            ),

            // Floating sparkles
            Positioned(
              top: 15,
              right: 25,
              child: Icon(
                Icons.auto_awesome,
                color: const Color(0xFFFFD700).withOpacity(0.7),
                size: 22.sp,
              ),
            ),
            Positioned(
              top: 28,
              right: 55,
              child: Icon(
                Icons.auto_awesome,
                color: const Color(0xFFFFD700).withOpacity(0.5),
                size: 14.sp,
              ),
            ),
            Positioned(
              top: 20,
              left: 35,
              child: Icon(
                Icons.auto_awesome,
                color: const Color(0xFFFFD700).withOpacity(0.6),
                size: 18.sp,
              ),
            ),
            Positioned(
              bottom: 45,
              left: 25,
              child: Icon(
                Icons.eco,
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                size: 28.sp,
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 28.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gift Icon with enhanced design
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      Container(
                        width: 85.w,
                        height: 85.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF4CAF50).withOpacity(0.15),
                              const Color(0xFF4CAF50).withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                      // Middle ring
                      Container(
                        width: 72.w,
                        height: 72.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF81C784),
                              Color(0xFF66BB6A),
                              Color(0xFF4CAF50),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.4),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: EdgeInsets.all(2.5.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF66BB6A),
                                Color(0xFF4CAF50),
                                Color(0xFF388E3C),
                              ],
                            ),
                          ),
                          child: Icon(
                            _hasShared
                                ? Icons.check_circle_rounded
                                : Icons.card_giftcard_rounded,
                            size: 36.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 18.h),

                  // Title with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF2E7D32),
                        Color(0xFF388E3C),
                        Color(0xFF4CAF50),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      _hasShared
                          ? 'Thanks for sharing PlantFollow'
                          : 'Share PlantFollow\nwith a friend',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // Subtitle with better styling
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 7.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Text(
                      _hasShared
                          ? '🌿 Start identifying your favorite plants'
                          : 'Share PlantFollow with someone who loves plants',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5.sp,
                        color: const Color(0xFF2E7D32),
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  SizedBox(height: 22.h),

                  // Enhanced Action Button
                  Container(
                    width: double.infinity,
                    height: 52.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26.r),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF66BB6A),
                          Color(0xFF4CAF50),
                          Color(0xFF388E3C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.4),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _hasShared
                            ? () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool('first_time_home', false);
                                Navigator.pop(context);
                                Get.to(() => const ScanScreen());
                              }
                            : _handleShare,
                        borderRadius: BorderRadius.circular(26.r),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26.r),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(7.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _hasShared
                                        ? Icons.camera_alt_rounded
                                        : Icons.share_rounded,
                                    color: Colors.white,
                                    size: 19.sp,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  _hasShared ? 'Scan Now' : 'Share App',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 6.h),

                  // Small hint text
                  if (!_hasShared)
                    Text(
                      'Quick & Easy',
                      style: GoogleFonts.inter(
                        fontSize: 10.5.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
