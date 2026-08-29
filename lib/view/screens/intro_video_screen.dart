import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:plantidentifier/view/screens/purchase_paywall/paywall.dart';
import 'package:plantidentifier/view/screens/app_tracking/app_tracking_permission.dart';
import 'package:plantidentifier/services/notification_service.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isVideoCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/plantfollow.mp4');
      await _controller?.initialize();
      _controller?.setLooping(false);
      _controller?.setVolume(0.0); // Mute the video
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
        
        // Listen for video completion
        _controller?.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller != null &&
        _controller!.value.position >= _controller!.value.duration &&
        _controller!.value.duration.inMilliseconds > 0) {
      // Video completed, show next button
      if (mounted) {
        setState(() {
          _isVideoCompleted = true;
        });
      }
      // Remove listener to prevent multiple calls
      _controller?.removeListener(_videoListener);
    }
  }

  Future<void> _onNextButtonPressed() async {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
    }
    
    // Show app tracking permission after video (not as overlay)
    try {
      await TrackingPermission.requestTrackingPermission();
    } catch (e) {
      debugPrint('Error requesting tracking permission: $e');
    }
    
    // Wait a moment, then request notification permission
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Request notification permission after tracking (not as overlay)
    try {
      await NotificationService.requestPermissions();
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    
    // Wait a moment before showing paywall
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      _navigateToPaywall();
    }
  }

  void _navigateToPaywall() {
    Get.off(
      () => const PayWallScreen(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _skipVideo() async {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
      _controller = null;
    }
    
    // Show app tracking permission after skip action
    try {
      await TrackingPermission.requestTrackingPermission();
    } catch (e) {
      debugPrint('Error requesting tracking permission: $e');
    }
    
    // Wait a moment, then request notification permission
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Request notification permission after tracking (not as overlay)
    try {
      await NotificationService.requestPermissions();
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    
    // Wait a moment before showing paywall
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      _navigateToPaywall();
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9AC5BE),
      body: Stack(
        children: [
          // Video player positioned at bottom
          if (_isInitialized && !_hasError && _controller != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Transform.scale(
                scale: 1.2, // Make video a bit bigger
                alignment: Alignment.bottomCenter,
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load video',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _skipVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            ),

          // Next Button (shown when video is completed)
          if (_isVideoCompleted && _isInitialized && !_hasError)
            Positioned(
              bottom: 60.h,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _onNextButtonPressed,
                  child: Container(
                    height: 56.h,
                    width: 200.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6BBE66),
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    child: Center(
                      child: Text(
                        "Next",
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Positioned(
          //   top: MediaQuery.of(context).padding.top + 24,
          //   left: 16,
          //   right: 16,
          //   child: SafeArea(
          //     child: Center(
          //       child: Container(
          //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //         decoration: BoxDecoration(
          //           color: Colors.black.withOpacity(0.45),
          //           borderRadius: BorderRadius.circular(20),
          //         ),
          //         child: Text(
          //           'Your plant journey, beautifully simplified!',
          //           textAlign: TextAlign.center,
          //           style: GoogleFonts.poppins(
          //             fontSize: 18.sp,
          //             color: Colors.white,
          //             fontStyle: FontStyle.italic,
          //             letterSpacing: 0.5,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

