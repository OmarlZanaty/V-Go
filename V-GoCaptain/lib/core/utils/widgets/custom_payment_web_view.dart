import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../theming/app_colors.dart';
import '../../theming/app_style.dart';

class CustomPaymentWebView extends StatefulWidget {
  const CustomPaymentWebView({required this.url, super.key});

  final String url;

  @override
  State<CustomPaymentWebView> createState() => _CustomPaymentWebViewState();
}

class _CustomPaymentWebViewState extends State<CustomPaymentWebView> {
  bool _handled = false;

  void _checkResult(String url) {
    if (_handled) return;
    if (url.contains('success=true') || url.contains('success=false')) {
      _handled = true;
      Navigator.of(context).pop(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'صفحة الدفع',
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
      ),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(useWideViewPort: true),
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
