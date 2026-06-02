import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../helpers/extensions.dart';
import '../../theming/app_colors.dart';
import 'custom_app_bar.dart';
import 'custom_toastification.dart';

class CustomPaymentWebView extends StatefulWidget {
  const CustomPaymentWebView({required this.url, super.key});
  final String url;

  @override
  CustomPaymentWebViewState createState() => CustomPaymentWebViewState();
}

class CustomPaymentWebViewState extends State<CustomPaymentWebView> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            log(request.url);
            if (request.url.contains("success=true") &&
                request.url.startsWith(
                  'https://accept.paymobsolutions.com/api/acceptance',
                )) {
              successToast(context, 'عملية دفع ناجحة', 'تم دفع الرحلة بنجاح');
              context.pop();

              return NavigationDecision.navigate;
            } else if (request.url.contains("success=false")) {
              errorToast(context, 'حدث خطأ', 'فشلت عملية الدفع');
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'صفحة الدفع', showLogo: true),
      body: WebViewWidget(controller: _controller),
    );
  }
}
