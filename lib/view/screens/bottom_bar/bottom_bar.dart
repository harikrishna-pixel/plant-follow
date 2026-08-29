import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_ui_flutter/views/paywall_view.dart';

import '../ai_chat_botanist/chat_history_screen.dart';
import '../favourite_screen/favourite_screens.dart';
import '../favourite_screen/folder_manager.dart';
import '../favourite_screen/my_garden_screen.dart';
import '../home_screen.dart';
import '../more_screen/more_screen.dart';
import '../scan_screen.dart';

class BottomNavExample extends StatefulWidget {
  const BottomNavExample({super.key});

  @override
  State<BottomNavExample> createState() => _BottomNavExampleState();
}

class _BottomNavExampleState extends State<BottomNavExample> {
  int _currentIndex = 0;
  bool _isKeyboardVisible = false;

  // Define your screens here
  final List<Widget> _screens = [
    const HomeScreen(), // Your home screen
    const MyGardenScreen(), // My Garden screen with tabs
    const ScanScreen(), // This won't be shown in PageView
    const ChatHistoryScreen(), // Chat history with AI Botanist button
    const MoreScreen(), // Your profile screen
  ];

  void _onItemTapped(int index) {
    // Handle center button separately - navigate to scan screen
    if (index == 2) {
      Get.to(() => const ScanScreen());
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if keyboard is visible
    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    // Hide FAB only when keyboard visible (keeps Scan icon always accessible)
    final shouldHideFAB = _isKeyboardVisible;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Floating Action Button - hidden on chat screen and when keyboard is visible
      floatingActionButton: shouldHideFAB ? null : Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // boxShadow: [
          //   BoxShadow(
          //     color: const Color(0xFF2E7D32).withOpacity(0.3),
          //     blurRadius: 12,
          //     offset: const Offset(0, 4),
          //   ),
          // ],
        ),
        child: FloatingActionButton(
          heroTag: 'bottom_bar_scan_fab',
          onPressed: () => _onItemTapped(2),
          backgroundColor: Colors.green,
          shape: CircleBorder(),
          elevation: 0,
          child: Image.asset(
            'assets/bottom_bar_icon/scan.png',
            width: 39,
            height: 39,
            // color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8,
        // color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home
              _buildNavItem(
                iconPath: 'assets/bottom_bar_icon/home-2.png',
                index: 0,
                label: 'Home',
              ),

              // Favorites
              _buildNavItem(
                iconPath: 'assets/bottom_bar_icon/flower 4.png',
                index: 1,
                label: 'My Garden',
              ),

              // Spacer for FAB
              const SizedBox(width: 64),

              // Chat
              _buildNavItem(
                iconPath: 'assets/bottom_bar_icon/chat.png',
                index: 3,
                label: 'Ask Me',
              ),

              // Profile
              _buildNavItem(
                iconPath: 'assets/bottom_bar_icon/category.png',
                index: 4,
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String iconPath,
    required int index,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;

    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: MaterialStateProperty.resolveWith((_) => Colors.transparent),
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconPath,
              width: 26,
              height: 26,
              color: isActive ? const Color(0xFF2E7D32) : Colors.grey[400],
            ),
            label != 'Chat' ? Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? const Color(0xFF2E7D32) : Colors.grey[600],
              ),
            ) : const SizedBox.shrink(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}