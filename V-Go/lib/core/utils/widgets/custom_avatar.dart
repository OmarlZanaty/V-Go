import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../helpers/extensions.dart';
import '../../theming/app_colors.dart';

class CustomAvatar extends StatelessWidget {
  const CustomAvatar({
    super.key,
    this.imageUrl,
    this.radius,
    this.whiteBackground = false,
    this.showOutlineBorder = false,
    this.iconColor,
  });
  final String? imageUrl;
  final double? radius;
  final bool whiteBackground;
  final Color? iconColor;
  final bool showOutlineBorder;
  @override
  Widget build(BuildContext context) {
    return (!imageUrl.isNullOrEmpty() && showOutlineBorder)
        ? Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary),
            ),
            child: _customCircleAvatar(),
          )
        : _customCircleAvatar();
  }

  CircleAvatar _customCircleAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: whiteBackground
          ? AppColors.white
          : AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: imageUrl.isNullOrEmpty()
          ? null
          : CachedNetworkImageProvider(imageUrl!),
      child: imageUrl.isNullOrEmpty()
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              color: iconColor ?? AppColors.primary,
              size: radius != null ? (radius! * 0.8) : 24,
            )
          : null,
    );
  }
}
