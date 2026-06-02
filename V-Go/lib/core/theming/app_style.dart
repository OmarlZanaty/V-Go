import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'font_weight_helper.dart';

abstract class AppStyle {
  // Regular styles
  static TextStyle styleRegular12 = GoogleFonts.tajawal(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
  );
  static TextStyle styleRegular14 = GoogleFonts.tajawal(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
  );
  static TextStyle styleRegular16 = GoogleFonts.tajawal(
    fontSize: 16.sp,
    fontWeight: FontWeightHelper.regular,
  );

  // Medium styles
  static TextStyle styleMedium10 = GoogleFonts.tajawal(
    fontSize: 10.sp,
    fontWeight: FontWeightHelper.medium,
  );
  static TextStyle styleMedium12 = GoogleFonts.tajawal(
    fontSize: 12.sp,
    fontWeight: FontWeightHelper.medium,
  );
  static TextStyle styleMedium14 = GoogleFonts.tajawal(
    fontSize: 14.sp,
    fontWeight: FontWeightHelper.medium,
  );
  static TextStyle styleMedium16 = GoogleFonts.tajawal(
    fontSize: 16.sp,
    fontWeight: FontWeightHelper.medium,
  );
  static TextStyle styleMedium18 = GoogleFonts.tajawal(
    fontSize: 18.sp,
    fontWeight: FontWeightHelper.medium,
  );

  // Bold styles
  static TextStyle styleBold20 = GoogleFonts.tajawal(
    fontSize: 20.sp,
    fontWeight: FontWeightHelper.bold,
  );
  static TextStyle styleBold22 = GoogleFonts.tajawal(
    fontSize: 22.sp,
    fontWeight: FontWeightHelper.bold,
  );
  static TextStyle styleBold24 = GoogleFonts.tajawal(
    fontSize: 24.sp,
    fontWeight: FontWeightHelper.bold,
  );
  static TextStyle styleBold38 = GoogleFonts.tajawal(
    fontSize: 38.sp,
    fontWeight: FontWeightHelper.bold,
  );
}
