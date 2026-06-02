import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';

class PdfView extends StatefulWidget {
  const PdfView({
    super.key,
    this.assetPath = 'assets/files/policy.pdf',
    this.title = 'سياسة الخصوصية',
  });

  final String assetPath;
  final String title;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  String? _pdfPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfFromAssets();
  }

  Future<void> _loadPdfFromAssets() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(widget.assetPath);
      final bytes = data.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = widget.assetPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      setState(() {
        _pdfPath = tempFile.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: widget.title),
      body: _isLoading
          ? const CustomLoadingWidget()
          : _pdfPath != null
          ? PDFView(
              filePath: _pdfPath,
              autoSpacing: false,
              pageFling: false,
              backgroundColor: AppColors.black,
              nightMode: true,
            )
          : const CustomFailureWidget(text: 'حدث خطأ اثناء تحميل الملف'),
    );
  }
}
