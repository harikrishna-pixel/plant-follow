import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';
import 'package:plantidentifier/view/screens/purchase_paywall/paywall.dart';
import 'package:plantidentifier/view/screens/home_screen.dart';
import 'package:plantidentifier/view/screens/intro_video_screen.dart';
import 'package:plantidentifier/view/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plantidentifier/services/notification_service.dart';
import 'package:plantidentifier/view/screens/app_tracking/app_tracking_permission.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _navigateAfterDelay();
  }

  /// Request permissions after splash screen logo appears
  Future<void> _requestPermissions() async {
    // Wait for splash screen to show (logo animation)
    await Future.delayed(4000.ms);

    if (!mounted) return;

    // Don't request any permissions here
    // App tracking and notification permissions will be requested after video
    _permissionsRequested = true;
  }

  /// Navigate to next screen after delay
  Future<void> _navigateAfterDelay() async {
    await Future.delayed(5500.ms);
    if (!mounted) return;

    final onboardingComplete = await _ensureOnboardingCompleted();
    if (!onboardingComplete || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final firstLaunchComplete = prefs.getBool('first_launch_complete') ?? false;
    
    // If first launch flow is already complete, go directly to home
    if (firstLaunchComplete) {
      if (!mounted) return;
      Get.off(() => const BottomNavExample());
      return;
    }

    final isFirstLaunch = prefs.getBool('first_launch') ?? true;
    final hasSeenVideo = prefs.getBool('intro_video_shown') ?? false;

    if (isFirstLaunch) {
      await prefs.setBool('first_launch', false);

      // Show video first if not seen yet
      if (!hasSeenVideo) {
        await prefs.setBool('intro_video_shown', true);
        Get
            .off(
              () => const IntroVideoScreen(),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 400),
        );
        return; // Don't continue to login/home, let video screen handle navigation
      } else {
        // Video already shown, go directly to paywall
        Get.off(
              () => const PayWallScreen(),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 400),
        );
        return; // Don't continue to login/home, let paywall handle navigation
      }
    }

    if (!mounted) return;

    Get.off(() => const BottomNavExample());
  }

  Future<bool> _ensureOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_complete') ?? false;
    if (completed) {
      return true;
    }

    final result = await Get.to<bool>(
      () => OnboardingScreen(
        onDone: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_complete', true);
          Get.back(result: true);
        },
      ),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 300),
    );

    if (result == true) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8F4EC),
              Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child: Image.asset("assets/logo.png",height: 110.h,width: 110.w,)
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'PlantFollow',
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 12,
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 1000.ms, delay: 200.ms)
                  .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
              ),
              const SizedBox(height: 12),
              // Text(
              //   'Welcome to PlantFollow',
              //   style: GoogleFonts.poppins(
              //     fontSize: 24,
              //     color: Colors.white,
              //     fontWeight: FontWeight.w600,
              //     letterSpacing: 0.5,
              //   ),
              // ).animate().fadeIn(duration: 1200.ms, delay: 400.ms),
              // const SizedBox(height: 8),
              // Text(
              //   'Your plant journey, beautifully simplified!',
              //   style: GoogleFonts.inter(
              //     fontSize: 16,
              //     color: Colors.white70,
              //     fontWeight: FontWeight.w400,
              //     letterSpacing: 0.3,
              //   ),
              // ).animate().fadeIn(duration: 1200.ms, delay: 500.ms),
              const SizedBox(height: 30),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                strokeWidth: 2.5,
              ).animate().fadeIn(duration: 1200.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}