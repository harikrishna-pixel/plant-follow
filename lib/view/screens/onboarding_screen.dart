import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/view/screens/intro_video_screen.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/privacy.dart';
import 'package:plantidentifier/view/screens/privacy_and_terms/terms.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: const [
              OnboardingPage1(),     // Welcome + GIF
              QuestionPage(),        // What brings you here?
              OnboardingPage2(),     // Identify plant
              OnboardingPage3(),     // Keep healthy
              OnboardingPage4(),     // Grow collection
              OnboardingPage5(),     // Share findings
            ],
          ),
          // Dot Indicator
          Positioned(
            bottom: 150.h,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 6,
                effect: ExpandingDotsEffect(
                  dotHeight: 8.h,
                  dotWidth: 8.w,
                  activeDotColor: const Color(0xFF6BBE66),
                  dotColor: Colors.grey.shade300,
                  expansionFactor: 4,
                  spacing: 6.w,
                ),
              ),
            ),
          ),
          // Next / Get Started Button (always visible at bottom)
          Positioned(
            bottom: 60.h,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_currentPage == 5) {
                    // Last page → mark onboarding as complete and go to IntroVideoScreen
                    widget.onDone();
                    Get.offAll(() => const IntroVideoScreen());
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  height: 56.h,
                  width: 200.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6BBE66),
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                  child: Center(
                    child: Text(
                      _currentPage == 5 ? "Get Started" : "Next",
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
        ],
      ),
    );
  }
}

// ====================== PAGE 1 ======================
class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 150.h),
        Container(
          height: 250.h,
          width: 250.w,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/onboard_animation/gif 2.gif"),
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 30.h),
        Text(
          "Welcome to PlantFollow",
          style: GoogleFonts.dmSans(
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          "Your journey as a plant lover starts here.",
          style: GoogleFonts.dmSans(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF666666),
            height: 1.5,
          ),
        ),
        // Footer text - positioned higher
        Spacer(),
        Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: Colors.grey.shade600,
              ),
              children: [
                const TextSpan(text: "By Continuing, You Accept our\n"),

                // Privacy Policy
                TextSpan(
                  text: "Privacy Policy",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Get.to(() => PrivacyScreen());
                    },
                ),

                const TextSpan(text: " & "),

                // Terms & Conditions
                TextSpan(
                  text: "Terms & Conditions",
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Get.to(() => TermsAndConditions());
                    },
                ),
              ],
            ),
          ),
        )

      ],
    );
  }
}

// ====================== QUESTION PAGE ======================
class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key});

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  String? _selectedOption;
  final options = [
    "Identify unknown plants",
    "Diagnose plant problems",
    "Improve plant care",
    "Track my plants",
    "I'm just curious"
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 120.h),
      child: Column(
        children: [
          SizedBox(height: 80.h),
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              image: const DecorationImage(
                image: AssetImage("assets/logo.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "What brings you to\nPlantFollow?",
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 28.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          SizedBox(height: 40.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: options.map((option) {
                final isSelected = _selectedOption == option;
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedOption = option),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFe8ffdf) : Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6BBE66) : const Color(0xFFE0E0E0),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.dmSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.black :  Color(0xFF424242),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================== PAGE 2-5 (Your original Test2-Test5) ======================
class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) => const _OnboardingTemplate(
    gif: "assets/onboard_animation/gif 3.gif",
    title: "Identify Any Plant in Seconds",
    subtitle: "Snap a photo and instantly know its name,\nspecies, and story.",
  );
}

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) => const _OnboardingTemplate(
    gif: "assets/onboard_animation/gif 5.gif",
    title: "Keep Your Plants Healthy",
    subtitle: "Spot problems early and learn exactly\nhow to fix them.",
  );
}

class OnboardingPage4 extends StatelessWidget {
  const OnboardingPage4({super.key});

  @override
  Widget build(BuildContext context) => const _OnboardingTemplate(
    gif: "assets/onboard_animation/gif 1.gif",
    title: "Grow Your Plant Collection",
    subtitle: "Save every plant you scan and build your\nown green collection",
  );
}

class OnboardingPage5 extends StatelessWidget {
  const OnboardingPage5({super.key});

  @override
  Widget build(BuildContext context) => const _OnboardingTemplate(
    gif: "assets/onboard_animation/gif 4.gif",
    title: "Share Your Plant Findings",
    subtitle: "Share your best plant discoveries with\nanyone, effortlessly.",
  );
}

// Reusable template for pages 2-5
class _OnboardingTemplate extends StatelessWidget {
  final String gif;
  final String title;
  final String subtitle;
  const _OnboardingTemplate({
    required this.gif,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 180.h),
        Container(
          height: 280.h,
          width: 280.w,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(gif),
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 30.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: Colors.black,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}