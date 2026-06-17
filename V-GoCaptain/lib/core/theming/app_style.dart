import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract class AppStyle {
  static TextStyle get heading => GoogleFonts.cairo(
        fontSize: 22.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      );

  static TextStyle get title => GoogleFonts.cairo(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.white,
      );

  static TextStyle get body => GoogleFonts.cairo(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.white,
      );

  static TextStyle get hint => GoogleFonts.cairo(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.grey,
      );

  static TextStyle get button => GoogleFonts.cairo(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.black,
      );

  // Client-parity styles (used by the shared auth widgets ported from the
  // client app so the captain login matches it pixel-for-pixel).
  static TextStyle get styleRegular14 => GoogleFonts.cairo(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.white,
      );

  static TextStyle get styleMedium14 => GoogleFonts.cairo(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
      );

  static TextStyle get styleMedium16 => GoogleFonts.cairo(
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
      );

  static TextStyle get styleMedium18 => GoogleFonts.cairo(
        fontSize: 18.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
      );
}
