import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class LocalHtmlScreen extends StatefulWidget {
  const LocalHtmlScreen({super.key});

  @override
  State<LocalHtmlScreen> createState() => _LocalHtmlScreenState();
}

class _LocalHtmlScreenState extends State<LocalHtmlScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    _loadHtmlFromAssets();
  }

  Future<void> _loadHtmlFromAssets() async {
    final htmlContent = await rootBundle.loadString('assets/PlantIdentifier_FAQ.html');
    _controller.loadHtmlString(htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text('Subscription Info',style: GoogleFonts.poppins(textStyle: TextStyle(fontSize: 17,fontWeight: FontWeight.w500,color: Colors.white)),),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
