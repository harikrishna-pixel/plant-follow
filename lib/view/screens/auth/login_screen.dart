import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/services/auth_service.dart';
import 'package:plantidentifier/view/screens/bottom_bar/bottom_bar.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/terms.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/privacy.dart';
import 'package:plantidentifier/mixpanel/mixpanel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Track Login Screen view
    MixpanelService.trackLoginScreen();
  }

  Future<void> _handleGoogleSignIn() async {
    await _runAuthFlow(() async {
      final credential = await AuthService.instance.signInWithGoogle();
      if (credential == null) {
        throw Exception('Sign-in cancelled');
      }
    });
  }

  Future<void> _handleAppleSignIn() async {
    await _runAuthFlow(() async {
      try {
        final userCredential = await AuthService.instance.signInWithApple();
        if (userCredential.user == null) {
          throw Exception('Apple Sign-In failed: No user returned. Please try again.');
        }
      } catch (e) {
        // Re-throw to be handled by _runAuthFlow
        rethrow;
      }
    });
  }

  Future<void> _runAuthFlow(Future<void> Function() action) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Logged in successfully!'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Get.offAll(() => const BottomNavExample());
    } catch (e) {
      if (!mounted) return;
      String message = 'Login failed. Please try again.';
      
      // Debug: Print the actual error for troubleshooting
      debugPrint('Login error: ${e.toString()}');
      debugPrint('Error type: ${e.runtimeType}');
      
      if (e is FirebaseAuthException) {
        debugPrint('Firebase Auth error code: ${e.code}');
        debugPrint('Firebase Auth error message: ${e.message}');
        
        switch (e.code) {
          case 'invalid-credential':
            message = 'Apple Sign-In failed. This may be a temporary issue. Please try signing in again. If the problem persists, check your internet connection.';
            break;
          case 'user-disabled':
            message = 'This account has been disabled.';
            break;
          case 'operation-not-allowed':
            message = 'Apple Sign-In is not enabled. Please contact support.';
            break;
          case 'network-request-failed':
            message = 'Network error. Please check your connection and try again.';
            break;
          case 'invalid-verification-code':
            message = 'Invalid verification. Please try signing in again.';
            break;
          case 'invalid-verification-id':
            message = 'Verification failed. Please try again.';
            break;
          case 'too-many-requests':
            message = 'Too many sign-in attempts. Please wait a moment and try again.';
            break;
          default:
            message = e.message ?? 'Apple Sign-In failed. Please try again.';
            if (message.isEmpty) {
              message = 'Apple Sign-In failed. Error code: ${e.code}';
            }
        }
      } else {
        final errorString = e.toString();
        debugPrint('Non-Firebase error: $errorString');
        
        if (errorString.contains('Exception:')) {
          message = errorString
              .replaceFirst(RegExp('^Exception: '), '')
              .trim();
        } else if (errorString.contains('Sign-in cancelled')) {
          // Don't show error for user cancellation
          message = '';
        } else if (errorString.isNotEmpty) {
          message = errorString;
        }
      }
      
      // Only show error if there's a message (skip cancellation)
      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(180),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(220),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🌱',
                                style: TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Welcome to PlantFollow',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Grow smarter, not harder!',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sign in once — we\'ll remember every plant, care tip, reminder, and reward for you.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFF7FFF9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1B5E20).withOpacity(0.25),
                                blurRadius: 30,
                                offset: const Offset(0, 20),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 64,
                                    width: 64,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4CAF50),
                                          Color(0xFF81C784),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.card_giftcard_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unlock your plant companion',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1B5E20),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Sync your plants and scans across devices.',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            height: 1.5,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 26),
                              _LoginButton(
                                icon: Image.asset('assets/google.png',
                                    width: 24, height: 24),
                                label: 'Continue with Google',
                                onTap: _handleGoogleSignIn,
                                isLoading: _isLoading,
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.black,
                              ),
                              if (Platform.isIOS) ...[
                                const SizedBox(height: 16),
                                _LoginButton(
                                  icon: const Icon(Icons.apple,
                                      size: 28, color: Colors.white),
                                  label: 'Continue with Apple',
                                  onTap: _handleAppleSignIn,
                                  isLoading: _isLoading,
                                  dark: true,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Your data stays private — only used to sync your plants.',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isLoading) ...[
                                const SizedBox(height: 24),
                                const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1B5E20)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),
                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.78),
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: 'By continuing, you agree to our '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () => Get.to(() => const TermsAndConditions()),
                                    child: Text(
                                      'Terms of Service',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () => Get.to(() => const PrivacyScreen()),
                                    child: Text(
                                      'Privacy Policy',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isLoading,
    this.dark = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool dark;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            backgroundColor ?? (dark ? Colors.black : Colors.white),
        foregroundColor:
            foregroundColor ?? (dark ? Colors.white : Colors.black87),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.78),
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
 