import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../navigation/v1_nav.dart';
import '../../../theme/plantfollow_colors.dart';
import '../../../theme/plantfollow_metrics.dart';
import '../../../theme/plantfollow_typography.dart';
import '../favourite_screen/my_garden_screen.dart';
import '../home_screen.dart';
import '../more_screen/more_screen.dart';
import '../camera/camera_entry_sheet.dart';
import '../progress/progress_screen.dart';

class BottomNavExample extends StatefulWidget {
  const BottomNavExample({super.key});

  @override
  State<BottomNavExample> createState() => _BottomNavExampleState();
}

class _BottomNavExampleState extends State<BottomNavExample> {
  int _currentIndex = V1Nav.todayIndex;

  final List<Widget> _screens = const [
    HomeScreen(),
    MyGardenScreen(),
    SizedBox.shrink(),
    ProgressScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    V1Nav.onSelectTab = _selectTab;
  }

  @override
  void dispose() {
    if (V1Nav.onSelectTab == _selectTab) {
      V1Nav.onSelectTab = null;
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == V1Nav.cameraActionIndex) return;
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _onItemTapped(int index) async {
    if (index == V1Nav.cameraActionIndex) {
      final mode = await showCameraEntrySheet(context);
      if (!mounted || mode == null) return;
      Get.to(() => cameraScreenFor(mode));
      return;
    }
    _selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
    final bottom = MediaQuery.of(context).padding.bottom;
    return Material(
      color: PlantFollowColors.surface,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: PlantFollowColors.surface,
          border: Border(
            top: BorderSide(color: PlantFollowColors.border, width: 0.5),
          ),
        ),
        padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8, top: 8),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny,
                index: V1Nav.todayIndex,
                label: V1Nav.todayLabel,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.local_florist_outlined,
                activeIcon: Icons.local_florist,
                index: V1Nav.plantsIndex,
                label: V1Nav.plantsLabel,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _CameraNavItem(onTap: () => onTap(V1Nav.cameraActionIndex)),
              _NavItem(
                icon: Icons.show_chart_outlined,
                activeIcon: Icons.show_chart,
                index: V1Nav.progressIndex,
                label: V1Nav.progressLabel,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                index: V1Nav.meIndex,
                label: V1Nav.meLabel,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _CameraNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: PlantFollowColors.primaryAction,
                shape: BoxShape.circle,
                boxShadow: PlantFollowShadows.camera,
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              V1Nav.cameraLabel,
              style: PlantFollowTypography.micro(
                color: PlantFollowColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final String label;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.index,
    required this.label,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    final color = isActive
        ? PlantFollowColors.primary
        : PlantFollowColors.inactive;
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
            Icon(isActive ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: PlantFollowTypography.micro(
                color: isActive
                    ? PlantFollowColors.primary
                    : PlantFollowColors.textSecondary,
                weight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
