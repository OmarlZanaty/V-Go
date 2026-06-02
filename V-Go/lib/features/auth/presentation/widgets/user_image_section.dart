import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';

class UserImageSection extends StatefulWidget {
  const UserImageSection({
    required this.onImageSelected,
    super.key,
    this.imageUrl,
  });
  final Function(File) onImageSelected;
  final String? imageUrl;
  @override
  State<UserImageSection> createState() => _UserImageSectionState();
}

class _UserImageSectionState extends State<UserImageSection> {
  File? _image;

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _image = File(image.path);
          widget.onImageSelected(_image!);
        });
      }
    } catch (e) {
      log('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        userImage(),
        Positioned(
          bottom: -10,
          right: -10,
          child: IconButton(
            onPressed: _pickImageFromGallery,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCamera01,
              color: AppColors.black,
              size: 22,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              shadowColor: AppColors.grey,
              elevation: 0.01,
            ),
          ),
        ),
      ],
    );
  }

  Widget userImage() {
    return _image != null
        ? ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(50)),
            child: Image.file(
              _image!,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          )
        : CustomAvatar(imageUrl: widget.imageUrl, radius: 45);
  }
}
