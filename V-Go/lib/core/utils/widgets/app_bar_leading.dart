import 'package:flutter/material.dart';

import '../../helpers/extensions.dart';
import '../../theming/app_colors.dart';

AppBar appBarLeading(BuildContext context) {
  return AppBar(
    foregroundColor: AppColors.primary,
    elevation: 0,
    automaticallyImplyLeading: false,
    forceMaterialTransparency: true,
    backgroundColor: Colors.transparent,
    leading: IconButton(
      onPressed: () => context.pop(),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(10),
      ),
      icon: const Icon(Icons.arrow_back),
    ),
  );
}
