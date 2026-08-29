import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:plantidentifier/services/auth_service.dart';
import 'package:plantidentifier/services/plant_local.dart';
import 'package:plantidentifier/services/wallet_service.dart';
import 'package:plantidentifier/utils/app_version.dart';
import 'package:plantidentifier/view/screens/auth/login_screen.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/privacy.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/review.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/restore_purchase.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/terms.dart';
import 'package:plantidentifier/view/screens/wallet/wallet_screen.dart';

import 'account_screen.dart';
import 'faq_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _clearLocalUserState(String uid) async {
    await LocalStorageService.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('free_scans_remaining');
    await prefs.remove('referral_prompt_shown_$uid');
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'Log out?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'You will need to sign in again to access your wallet and scans.',
              style: GoogleFonts.inter(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(),
                ),
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

    if (!confirm) return;

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

      Navigator.of(context, rootNavigator: true).pop();
      Fluttertoast.showToast(
        msg: 'You have been logged out.',
        toastLength: Toast.LENGTH_SHORT,
      );
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
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

  Future<void> _handleDeleteAccount(BuildContext context) async {
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

    final confirm = await showDialog<bool>(
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
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(),
                ),
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

    if (!confirm) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final uid = user.uid;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

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
          
          // Show appropriate error message
          String errorMsg = 'Could not delete account. Please try again later.';
          if (reauthError.toString().contains('cancel') || 
              reauthError.toString().contains('cancelled')) {
            errorMsg = 'Account deletion cancelled. Please try again later.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: GoogleFonts.inter(),
              ),
            ),
          );
          return;
        }
      } else {
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        }
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
    } catch (_) {}

    await _clearLocalUserState(uid);

    try {
      await AuthService.instance.signOut();
    } catch (_) {}

    Navigator.of(context, rootNavigator: true).pop();
    Fluttertoast.showToast(
      msg: 'Account deleted successfully.',
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.redAccent,
    );
    Get.offAll(() => const LoginScreen());
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    // Try to get version from package_info_plus first (most reliable - reads from built app)
    String version = AppVersion.version;
    String buildNumber = AppVersion.buildNumber;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (e) {
      // Use AppVersion as fallback if package_info_plus fails
      // AppVersion reads from environment or uses default
      debugPrint('Using AppVersion fallback: ${AppVersion.fullVersion}');
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'About',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // App Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset("assets/logo.png"),
                    ),
                    const SizedBox(height: 24),
                    // App Name
                    Text(
                      'PlantFollow',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your AI-powered Plant care companion',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Version Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50).withOpacity(0.1),
                            const Color(0xFF66BB6A).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified,
                            color: const Color(0xFF4CAF50),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Version $version',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                          // if (buildNumber.isNotEmpty) ...[
                          //   const SizedBox(width: 8),
                          //   Container(
                          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          //     decoration: BoxDecoration(
                          //       color: const Color(0xFF4CAF50).withOpacity(0.15),
                          //       borderRadius: BorderRadius.circular(8),
                          //     ),
                          //     child: Text(
                          //       '',
                          //       style: GoogleFonts.inter(
                          //         fontSize: 11,
                          //         fontWeight: FontWeight.w500,
                          //         color: const Color(0xFF2E7D32),
                          //       ),
                          //     ),
                          //   ),
                          // ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF4),
      appBar: AppBar(
        title: Text(
          'More',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _HeroCard(user: user),
              // const SizedBox(height: 24),
              _SectionHeader(title: 'General'),
              _CardGroup(
                children: [
                  _MoreTile(
                    icon: Icons.person_rounded,
                    title: 'Account',
                    subtitle: 'View your profile and referral info',
                    onTap: () => Get.to(() => const AccountScreen()),
                  ),
                  _MoreTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Wallet',
                    subtitle: 'Check available scans and rewards',
                    onTap: () => Get.to(() => const WalletScreen()),
                  ),
                  _MoreTile(
                    icon: Icons.star_rate_rounded,
                    title: 'Rate Us',
                    subtitle: 'Tell others what you think',
                    onTap: RateApp.rateApp,
                  ),
                  _MoreTile(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    onTap: () => Get.to(() => PrivacyScreen()),
                  ),
                  _MoreTile(
                    icon: Icons.article_rounded,
                    title: 'Terms of Service',
                    subtitle: 'Understand the rules of use',
                    onTap: () => Get.to(() => TermsAndConditions()),
                  ),
                  _MoreTile(
                    icon: Icons.help_outline_rounded,
                    title: 'FAQ',
                    subtitle: 'Frequently Asked Questions',
                    onTap: () => Get.to(() => const FAQScreen()),
                  ),
                  _MoreTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'App version',
                    onTap: () => _showAboutDialog(context),
                  ),
                  _MoreTile(
                    icon: Icons.refresh_rounded,
                    title: 'Restore',
                    subtitle: 'Restore your previous purchases',
                    onTap: () => PurchaseHelper.restorePurchases(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionHeader(title: 'Account Actions'),
              _CardGroup(
                children: [
                  _MoreTile(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    subtitle: 'Sign out of this device',
                    onTap: () => _handleLogout(context),
                  ),
                  _MoreTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete Account',
                    subtitle: 'Remove your data permanently',
                    iconColor: Colors.redAccent,
                    textColor: Colors.redAccent,
                    onTap: () => _handleDeleteAccount(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? const Color(0xFF1B5E20);
    final effectiveTitleColor = textColor ?? Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.08),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: effectiveIconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: effectiveIconColor,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: effectiveTitleColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName?.trim();
    final email = user?.email ?? 'Not provided';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName?.isNotEmpty == true ? displayName! : 'Plant Lover',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Access your profile, rewards, and privacy settings all from one place.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.92),
                    ),
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

class _CardGroup extends StatelessWidget {
  const _CardGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.08),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
