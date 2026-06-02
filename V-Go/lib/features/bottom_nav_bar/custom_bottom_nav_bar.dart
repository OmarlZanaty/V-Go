import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theming/app_colors.dart';

class CustomBottomNavBar extends StatefulWidget {
  const CustomBottomNavBar({
    required this.onTabTapped,
    super.key,
    this.isDriver = false,
  });
  final void Function(int index) onTabTapped;
  final bool isDriver;
  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(38),
          topRight: Radius.circular(38),
        ),
        color: AppColors.lightWhite,
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SlideInLeft(
            from: 400,
            child: _buildNavItem(HugeIcons.strokeRoundedHome04, 0),
          ),
          SlideInLeft(
            from: 400,
            delay: const Duration(milliseconds: 75),
            child: _buildNavItem(HugeIcons.strokeRoundedRoute03, 1),
          ),
          SlideInLeft(
            from: 400,
            delay: const Duration(milliseconds: 150),
            child: _buildNavItem(
              widget.isDriver
                  ? HugeIcons.strokeRoundedNotification03
                  : HugeIcons.strokeRoundedUser,
              2,
            ),
          ),
          SlideInLeft(
            from: 400,
            delay: const Duration(milliseconds: 225),
            child: _buildNavItem(HugeIcons.strokeRoundedSettings02, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = currentIndex == index;
    return IconButton(
      onPressed: () {
        if (currentIndex != index) {
          setState(() {
            currentIndex = index;
            widget.onTabTapped(index);
          });
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.primary.withValues(alpha: 0.18)
            : null,
      ),
      icon: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 0),
        child: HugeIcon(
          icon: icon,
          color: isSelected ? AppColors.primary : Colors.grey[300]!,
          size: isSelected ? 24 : 26,
        ),
      ),
    );
  }
}
