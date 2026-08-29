import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late double height;
  late double width;

  InAppWebViewController? webViewController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternetConnection();
    });
  }

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

  Future<void> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showInternetErrorToast();
      return;
    }

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      _showInternetErrorToast();
    }
  }

  void _showInternetErrorToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /// Define Sizes //
    var size = MediaQuery.of(context).size;
    height = size.height;
    width = size.width;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        height = constraints.maxHeight;
        width = constraints.maxWidth;
        if (width <= 1200) {
          return _smallBuildLayout();
        } else {
          return const Text("Please Make Sure Your Device is in Portrait view");
        }
      },
    );
  }

  Widget _smallBuildLayout() {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            Get.back();
          },
          child: Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri("https://marberx.com/plant-identifier-privacy.html"),
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          // Set the InAppWebView options to disable scrollbars
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              verticalScrollBarEnabled: false,
              horizontalScrollBarEnabled: false,
            ),
          ),
          onLoadStop: (controller, url) async {
            // Apply more thorough CSS to hide scrollbars in various browsers
            await controller.evaluateJavascript(
              source: """
    var style = document.createElement('style');
    style.innerHTML = `
      /* Hide scrollbar for Chrome, Safari and Opera */
      ::-webkit-scrollbar {
        display: none !important;
        width: 0 !important;
        height: 0 !important;
        background: transparent !important;
      }
      
      /* Hide scrollbar for IE, Edge and Firefox */
      * {
        -ms-overflow-style: none !important;  /* IE and Edge */
        scrollbar-width: none !important;     /* Firefox */
      }
      
      /* Additional styles to ensure scrollbars are hidden in all elements */
      html, body, div, section, article, aside, nav, main, header, footer {
        -ms-overflow-style: none !important;
        scrollbar-width: none !important;
        overflow: -moz-scrollbars-none !important;
      }

      /* Ensure overflow doesn't show scrollbars but still allows scrolling */
      body {
        overflow-y: auto !important;
        overflow-x: hidden !important;
      }
    `;
    document.head.appendChild(style);
    
    // Apply to any iframes that might exist or be created
    const iframes = document.querySelectorAll('iframe');
    iframes.forEach(iframe => {
      try {
        if (iframe.contentDocument) {
          const frameStyle = document.createElement('style');
          iframe.contentDocument.head.appendChild(frameStyle);
          frameStyle.innerHTML = style.innerHTML;
        }
      } catch (e) {
        console.log('Could not access iframe content: ', e);
      }
    });
  """,
            );
          },
        ),
      ),
    );
  }
}
