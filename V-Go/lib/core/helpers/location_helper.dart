import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationHelper {
  /// Checks if location services are enabled and permissions are granted.
  /// If not, shows a dialog to guided the user to settings.
  static Future<bool> checkLocationRequirements(BuildContext context) async {
    try {
      // 1. Check if location services are enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          await _showLocationDialog(
            context: context,
            title: 'خدمات الموقع معطلة',
            desc:
                'يرجى تفعيل خدمات الموقع لتتمكن من استخدام التطبيق بشكل صحيح.',
            onConfirm: () async => await Geolocator.openLocationSettings(),
          );
        }
        return false;
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            await _showLocationDialog(
              context: context,
              title: 'إذن الموقع مطلوب',
              desc:
                  'يحتاج التطبيق إلى الوصول للموقع لتقديم الخدمات القريبة منك.',
              onConfirm: () async => await Geolocator.requestPermission(),
            );
          }
          return false;
        }
      }


      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await _showLocationDialog(
            context: context,
            title: 'إذن الموقع مرفوض دائمًا',
            desc:
                'لقد تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من إعدادات التطبيق.',
            onConfirm: () async => await Geolocator.openAppSettings(),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking location: $e');
      return false;
    }
  }

  static Future<void> _showLocationDialog({
    required BuildContext context,
    required String title,
    required String desc,
    required VoidCallback onConfirm,
  }) async {
    return AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      dialogBackgroundColor: const Color(
        0xFF1E1E1E,
      ), // Slightly lighter than app black for depth
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFdce01e).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFFdce01e),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              desc,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFdce01e),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'فتح الإعدادات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).show();
  }
}
