import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/models/verification_models.dart';
import '../cubit/verification_cubit.dart';

class VerificationView extends StatefulWidget {
  const VerificationView({super.key});

  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<VerificationCubit>();
    if (cubit.state.status == VerificationLoadStatus.initial) cubit.load();
  }

  Future<void> _pickAndUpload(DriverDocumentType type) async {
    final source = type == DriverDocumentType.selfie
        ? ImageSource.camera
        : await _chooseSource();
    if (source == null) return;

    DateTime? expiryDate;
    if (type.requiresExpiry) {
      expiryDate = await _pickExpiryDate();
      if (expiryDate == null) return;
    }

    final picked = await _picker.pickImage(
      source: source,
      preferredCameraDevice: type == DriverDocumentType.selfie
          ? CameraDevice.front
          : CameraDevice.rear,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    if (type == DriverDocumentType.selfie) {
      final confirmed = await _confirmSelfie(picked.path);
      if (!confirmed) return;
    }
    if (!mounted) return;
    context.read<VerificationCubit>().uploadDocument(
      type: type,
      filePath: picked.path,
      expiryDate: expiryDate,
    );
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.darkGrey,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primary,
              ),
              title: Text('تصوير بالكاميرا', style: AppStyle.body),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: Text('اختيار من المعرض', style: AppStyle.body),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickExpiryDate() {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day + 1),
      lastDate: DateTime(now.year + 15),
      initialDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'اختار تاريخ انتهاء الرخصة',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
  }

  Future<bool> _confirmSelfie(String path) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: Text('تأكيد الصورة الشخصية', style: AppStyle.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.file(File(path), height: 260.h, fit: BoxFit.cover),
            ),
            SizedBox(height: 12.h),
            Text(
              'صورة واضحة لوشّك — هتظهر للعملاء',
              style: AppStyle.hint,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('إعادة التصوير', style: AppStyle.hint),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('رفع الصورة', style: AppStyle.button),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'توثيق الحساب',
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
      ),
      body: BlocConsumer<VerificationCubit, VerificationState>(
        listenWhen: (previous, current) =>
            previous.error != current.error ||
            previous.success != current.success,
        listener: (context, state) {
          if (state.error != null) errorToast(context, 'حدث خطأ', state.error!);
          if (state.success != null)
            successToast(context, 'تم', state.success!);
        },
        builder: (context, state) {
          if (state.status == VerificationLoadStatus.loading &&
              state.verification == null) {
            return const Center(
              child: SpinKitThreeBounce(color: AppColors.primary, size: 32),
            );
          }
          final verification = state.verification;
          if (verification == null) {
            return Center(
              child: Text('تعذّر تحميل حالة التوثيق', style: AppStyle.hint),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<VerificationCubit>().load(),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _Header(verification: verification),
                SizedBox(height: 16.h),
                ...DriverDocumentType.values.map(
                  (type) => _DocumentRow(
                    type: type,
                    document: verification.documentFor(type),
                    uploading: state.uploadingType == type,
                    progress: state.uploadProgress,
                    onUpload: () => _pickAndUpload(type),
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.verification});

  final DriverVerification verification;

  @override
  Widget build(BuildContext context) {
    final status = verification.status;
    final color = switch (status) {
      VerificationStatus.approved => AppColors.success,
      VerificationStatus.rejected ||
      VerificationStatus.suspended => AppColors.danger,
      VerificationStatus.underReview => AppColors.primaryOrange,
      VerificationStatus.pendingDocuments => AppColors.primary,
    };
    final note = (verification.note ?? '').trim();
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24.r,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(Icons.verified_user_outlined, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: AppStyle.title.copyWith(color: color),
                ),
                if (note.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(note, style: AppStyle.hint),
                ],
                if ((verification.blockMessage ?? '').isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(verification.blockMessage!, style: AppStyle.hint),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.type,
    required this.document,
    required this.uploading,
    required this.progress,
    required this.onUpload,
  });

  final DriverDocumentType type;
  final DriverDocument? document;
  final bool uploading;
  final double progress;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final approved = doc?.status == DriverDocumentStatus.approved;
    final label = doc == null ? 'لم يُرفع' : doc.status.label;
    final reason = (doc?.rejectionReason ?? '').trim();
    final color = doc == null
        ? AppColors.grey
        : approved
        ? AppColors.success
        : doc.status == DriverDocumentStatus.rejected
        ? AppColors.danger
        : AppColors.primaryOrange;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: _cardDecoration(radius: 14),
      child: Row(
        children: [
          Icon(_icon(type), color: AppColors.primary, size: 24.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label, style: AppStyle.body),
                SizedBox(height: 3.h),
                Text(label, style: AppStyle.hint.copyWith(color: color)),
                if (reason.isNotEmpty)
                  Text(reason, style: AppStyle.hint.copyWith(color: color)),
                if (type == DriverDocumentType.selfie)
                  Text(
                    'صورة واضحة لوشّك — هتظهر للعملاء',
                    style: AppStyle.hint.copyWith(fontSize: 12.sp),
                  ),
                if (uploading) ...[
                  SizedBox(height: 8.h),
                  LinearProgressIndicator(
                    value: progress <= 0 ? null : progress,
                    color: AppColors.primary,
                    backgroundColor: AppColors.lightWhite,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.w),
          TextButton.icon(
            onPressed: approved || uploading ? null : onUpload,
            icon: Icon(
              doc == null ? Icons.upload_file : Icons.refresh,
              color: approved ? AppColors.grey : AppColors.primary,
            ),
            label: Text(
              doc == null ? 'رفع' : 'إعادة رفع',
              style: AppStyle.body.copyWith(
                color: approved ? AppColors.grey : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _icon(DriverDocumentType type) {
  return switch (type) {
    DriverDocumentType.selfie => Icons.face_retouching_natural_outlined,
    DriverDocumentType.nationalIdFront => Icons.badge_outlined,
    DriverDocumentType.nationalIdBack => Icons.badge,
    DriverDocumentType.driverLicense => Icons.card_membership_outlined,
    DriverDocumentType.vehicleLicense => Icons.directions_car_outlined,
  };
}

BoxDecoration _cardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: AppColors.darkGrey,
    borderRadius: BorderRadius.circular(radius.r),
  );
}
