import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/di/di.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  bool _loading = true;
  String? _error;
  List<_Notif> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await getIt<ApiServices>().get(EndPoint.getNotifications);
      final list = res is List
          ? res
          : (res is Map ? (res['data'] ?? res['Data'] ?? res['items'] ?? []) : []);
      _items = (list as List)
          .whereType<Map>()
          .map((e) => _Notif.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = ServerFailure.fromError(e).errMessage;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('الإشعارات',
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: CacheHelper.getBool(AppConstants.notificationsMuted)
          ? _empty(Icons.notifications_off_outlined,
              'الإشعارات مُوقفة. يمكنك تفعيلها من الإعدادات.')
          : _loading
          ? const Center(
              child: SpinKitThreeBounce(color: AppColors.primary, size: 32))
          : _error != null
              ? _empty(Icons.error_outline, _error!)
              : _items.isEmpty
                  ? _empty(Icons.notifications_none, 'لا توجد إشعارات')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (_, i) => _tile(_items[i]),
                      ),
                    ),
    );
  }

  Widget _tile(_Notif n) => Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications, color: AppColors.primary, size: 24.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: AppStyle.body),
                  if (n.body.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(n.body, style: AppStyle.hint),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _empty(IconData icon, String text) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64.r, color: AppColors.grey),
            SizedBox(height: 12.h),
            Text(text, style: AppStyle.hint),
          ],
        ),
      );
}

class _Notif {
  final String title;
  final String body;
  _Notif({required this.title, required this.body});

  factory _Notif.fromJson(Map<String, dynamic> j) => _Notif(
        title: (j['title'] ?? j['Title'] ?? 'إشعار').toString(),
        body: (j['body'] ?? j['Body'] ?? j['message'] ?? j['Message'] ?? '')
            .toString(),
      );
}
