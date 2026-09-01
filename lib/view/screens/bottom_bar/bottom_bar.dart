import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../navigation/v1_nav.dart';
import '../favourite_screen/my_garden_screen.dart';
import '../home_screen.dart';
import '../more_screen/more_screen.dart';
import '../camera/camera_entry_sheet.dart';

class BottomNavExample extends StatefulWidget {
  const BottomNavExample({super.key});

  @override
  State<BottomNavExample> createState() => _BottomNavExampleState();
}

class _BottomNavExampleState extends State<BottomNavExample> {
  int _currentIndex = V1Nav.todayIndex;
  bool _isKeyboardVisible = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    MyGardenScreen(),
    SizedBox.shrink(),
    MoreScreen(),
  ];

  Future<void> _onItemTapped(int index) async {
    if (index == V1Nav.cameraActionIndex) {
      final mode = await showCameraEntrySheet(context);
      if (!mounted || mode == null) return;
      Get.to(() => cameraScreenFor(mode));
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final shouldHideFAB = _isKeyboardVisible;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: shouldHideFAB
          ? null
          : Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FloatingActionButton(
                heroTag: 'bottom_bar_scan_fab',
                onPressed: () => _onItemTapped(V1Nav.cameraActionIndex),
                backgroundColor: Colors.green,
                shape: const CircleBorder(),
                elevation: 0,
                child: Image.asset(
                  'assets/bottom_bar_icon/scan.png',
                  width: 39,
                  height: 39,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: V1BottomBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class V1BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const V1BottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              iconPath: 'assets/bottom_bar_icon/home-2.png',
              index: V1Nav.todayIndex,
              label: V1Nav.todayLabel,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              iconPath: 'assets/bottom_bar_icon/flower 4.png',
              index: V1Nav.plantsIndex,
              label: V1Nav.plantsLabel,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            const SizedBox(width: 64),
            _NavItem(
              iconPath: 'assets/bottom_bar_icon/category.png',
              index: V1Nav.meIndex,
              label: V1Nav.meLabel,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String iconPath;
  final int index;
  final String label;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.iconPath,
    required this.index,
    required this.label,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
        onTap: () => onTap(index),
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
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? const Color(0xFF2E7D32) : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
