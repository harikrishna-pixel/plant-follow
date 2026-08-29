import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/views/paywall_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home_screen.dart';
import 'package:plantidentifier/mixpanel/mixpanel.dart';

class PayWallScreen extends StatefulWidget {

  const PayWallScreen({super.key});

  @override

  State<PayWallScreen> createState() => _PayWallScreenState();

}

class _PayWallScreenState extends State<PayWallScreen> {

  Offering? offering;

  late ScaffoldMessengerState _scaffoldMessenger;

  @override

  void initState() {

    super.initState();
    // Track Paywall Screen view
    MixpanelService.trackPaywallScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      _scaffoldMessenger = ScaffoldMessenger.of(context);

      await _checkInternetOnEnter();

      // Load offerings AND current user subscription status immediately

      await _loadOfferingsAndCustomerInfo();

    });

  }

  Future<void> _loadOfferingsAndCustomerInfo() async {

    try {

      final offerings = await Purchases.getOfferings();

      final customerInfo = await Purchases.getCustomerInfo();

      setState(() {

        offering = offerings.current;

      });

      bool isSubscribed = customerInfo.entitlements.active.isNotEmpty;

      if (isSubscribed) {

        debugPrint("User is already subscribed!");

        // Optional: auto-navigate to HomeScreen

        // Get.offAll(() => const HomeScreen());

      }

    } catch (e) {

      debugPrint("Error fetching offerings or customer info: $e");

    }

  }

  /// ✅ Helper to check ACTUAL internet connectivity (not just WiFi)

  Future<bool> _hasInternet() async {

    try {

      final response = await http

          .get(Uri.parse('https://www.google.com/favicon.ico'))

          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;

    } catch (_) {

      return false;

    }

  }

  /// ✅ Run when entering screen
  Future<void> _checkInternetOnEnter() async {
    if (!mounted) return;

    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      await _showNoInternetAndGoBack();
      return;
    }

    final hasInternet = await _hasInternet();

    if (!hasInternet) {
      await _showNoInternetAndGoBack();
    }
  }

  /// Show loading animation, toast for 2 seconds, then navigate back
  Future<void> _showNoInternetAndGoBack() async {
    if (!mounted) return;
    
    // Show toast message
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Check your internet connection',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Show the loading animation + toast for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    // Navigate back if still mounted
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 🔄 Restore Purchases Logic (alert dialog for both success and failure)

  Future<void> _onTapRestore() async {

    try {

      final customerInfo = await Purchases.restorePurchases();

      final hasActive = customerInfo.entitlements.active.isNotEmpty;

      if (hasActive) {

        // Success alert

        await showDialog(

          context: context,

          builder: (_) => AlertDialog(

            title: const Text('Success'),

            content:

            const Text('Your purchases have been restored successfully!'),

            actions: [

              TextButton(

                onPressed: () async {
                  // Mark first launch as complete when restore succeeds
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('first_launch_complete', true);
                  
                  Navigator.pop(context); // dismiss dialog

                  Get.offAll(() => const HomeScreen()); // navigate

                },

                child: const Text('OK'),

              )

            ],

          ),

        );

      } else {

        // No active purchases

        await showDialog(

          context: context,

          builder: (_) => AlertDialog(

            title: const Text('Error'),

            content: const Text('No Active Plans Are Available!'),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(context),

                child: const Text('OK'),

              )

            ],

          ),

        );

      }

    } on PlatformException catch (e) {

      // Platform exception alert

      await showDialog(

        context: context,

        builder: (_) => AlertDialog(

          title: const Text('Restore Failed'),

          content: Text('${e.message ?? 'Please try again later.'}'),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(context),

              child: const Text('OK'),

            )

          ],

        ),

      );

    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F5),
      body: offering == null
          ? _buildLoadingState()
          : PaywallView(
              offering: offering!,
              displayCloseButton: true,
              onDismiss: () async {
                // Mark first launch as complete when paywall is dismissed
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('first_launch_complete', true);
                
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                } else {
                  Get.offAll(() => const BottomNavExample());
                }
              },
              onPurchaseCompleted:
                  (CustomerInfo customerInfo, StoreTransaction transaction) async {
                debugPrint(
                  'Purchase completed: ${transaction.productIdentifier}',
                );
                // Mark first launch as complete when purchase is completed
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('first_launch_complete', true);
                Navigator.pop(context);
              },
              onPurchaseError: (PurchasesError error) {
                debugPrint('Purchase error: $error');
              },
              onRestoreCompleted: (CustomerInfo customerInfo) async {
                // Mark first launch as complete when restore is completed
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('first_launch_complete', true);
                // Call the new restore logic
                _onTapRestore();
              },
            ),
    );
  }

  // Beautiful loading state card (similar to Weather Screen)
  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated plant icon
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1500),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Premium Plans',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please wait while we prepare\nyour exclusive offers',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // iOS-style loading indicator
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

