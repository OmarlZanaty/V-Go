import 'package:url_launcher/url_launcher.dart';
import '../utils/widgets/custom_toastification.dart';

Future<void> customUrlLauncher(context, String url) async {
  if (url != "") {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      errorToast(context, 'حدث خطا', 'لا يمكن فتح الرابط');
    }
  }
}