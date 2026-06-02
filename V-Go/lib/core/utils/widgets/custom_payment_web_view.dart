import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../helpers/extensions.dart';
import 'custom_app_bar.dart';
import 'custom_toastification.dart';

/// PayMob checkout. Uses flutter_inappwebview because webview_flutter mishandles
/// text-field focus on the card form (the cardholder-name field jumps to expiry
/// and can't be typed into) on Android.
class CustomPaymentWebView extends StatefulWidget {
  const CustomPaymentWebView({required this.url, super.key});
  final String url;

  @override
  CustomPaymentWebViewState createState() => CustomPaymentWebViewState();
}

class CustomPaymentWebViewState extends State<CustomPaymentWebView> {
  bool _handled = false;

  /// Inspect a URL for PayMob's success/failure callback and react once.
  void _checkResult(String url) {
    if (_handled) return;
    if (url.contains('success=true')) {
      _handled = true;
      successToast(context, 'عملية دفع ناجحة', 'تم دفع الرحلة بنجاح');
      context.pop();
    } else if (url.contains('success=false')) {
      _handled = true;
      errorToast(context, 'حدث خطأ', 'فشلت عملية الدفع');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'صفحة الدفع', showLogo: true),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          // JS, DOM storage and hybrid composition are on by default in
          // flutter_inappwebview; hybrid composition is what fixes the card
          // form's keyboard/focus handling on Android.
          initialSettings: InAppWebViewSettings(
            useWideViewPort: true,
            transparentBackground: true,
          ),
          onLoadStop: (controller, url) {
            if (url != null) _checkResult(url.toString());
          },
          onUpdateVisitedHistory: (controller, url, _) {
            if (url != null) _checkResult(url.toString());
          },
          onReceivedError: (controller, request, error) {
            log('Payment webview error: ${error.description}');
          },
        ),
      ),
    );
  }
}
