import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

/// Renders a bundled PDF (privacy / pricing / refund / contact policies).
class PdfViewerView extends StatefulWidget {
  const PdfViewerView({
    super.key,
    this.assetPath = 'assets/files/policy.pdf',
    this.title = 'سياسة الخصوصية',
  });

  final String assetPath;
  final String title;

  @override
  State<PdfViewerView> createState() => _PdfViewerViewState();
}

class _PdfViewerViewState extends State<PdfViewerView> {
  String? _pdfPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(widget.assetPath);
      final bytes = data.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.assetPath.split('/').last}');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _pdfPath = file.path;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: AppStyle.title.copyWith(color: AppColors.black)),
      ),
      body: _loading
          ? const Center(
              child: SpinKitThreeBounce(color: AppColors.primary, size: 32))
          : _pdfPath != null
              ? PDFView(
                  filePath: _pdfPath,
                  autoSpacing: false,
                  pageFling: false,
                  backgroundColor: AppColors.black,
                  nightMode: true,
                )
              : Center(
                  child: Text('حدث خطأ أثناء تحميل الملف', style: AppStyle.hint),
                ),
    );
  }
}
