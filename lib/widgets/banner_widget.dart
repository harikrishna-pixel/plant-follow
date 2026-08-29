import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/view/screens/purchase_paywall/paywall.dart';
import '../utils/banner_helper.dart';

class BannerWidget extends StatefulWidget {
  final String screenId;
  
  const BannerWidget({
    super.key,
    required this.screenId,
  });

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> {
  bool _shouldShow = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBannerVisibility();
  }

  Future<void> _checkBannerVisibility() async {
    final shouldShow = await BannerHelper.shouldShowBanner(widget.screenId);
    if (mounted) {
      setState(() {
        _shouldShow = shouldShow;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_shouldShow) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: (){
        Get.to(PayWallScreen());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/banner.png',
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              // If image fails to load, return empty widget
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

