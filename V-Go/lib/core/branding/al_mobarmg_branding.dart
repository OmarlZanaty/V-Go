import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// AL MOBARMG developer signature — the one place the software company's
/// branding is drawn. Used only on the login screen (compact) and in settings
/// (full); the native splash carries a static image of the same mark.
///
/// The whole block is a single tappable element that opens the company website
/// in the external browser. Static by design: no animation.
class AlMobarmgBranding extends StatelessWidget {
  /// "Developed by / AL MOBARMG" signature for the bottom of auth screens.
  const AlMobarmgBranding.compact({super.key, this.label = 'Developed by'})
    : _full = false;

  /// Logo + "AL MOBARMG / Software Company / almobarmg.com" card for settings.
  const AlMobarmgBranding.full({super.key}) : _full = true, label = null;

  final bool _full;
  final String? label;

  static final Uri website = Uri.parse('https://www.almobarmg.com');
  static const String websiteLabel = 'almobarmg.com';

  static const Color brandBlue = Color(0xFF29ABE2);
  static const Color brandNavy = Color(0xFF2B2E83);

  static Future<void> openWebsite(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(website, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Opening $website failed: $e');
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الموقع، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = dark ? Colors.white : const Color(0xFF1F2937);
    final secondary = dark ? Colors.white60 : const Color(0xFF6B7280);

    return Semantics(
      button: true,
      link: true,
      label: 'Visit AL MOBARMG Software Company website',
      excludeSemantics: true,
      child: _full
          ? _FullCard(dark: dark, name: name, secondary: secondary)
          : _Compact(label: label!, name: name, secondary: secondary),
    );
  }
}

class _Compact extends StatelessWidget {
  const _Compact({
    required this.label,
    required this.name,
    required this.secondary,
  });

  final String label;
  final Color name;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    // A signature reads left-to-right even inside the Arabic (RTL) screens.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: InkWell(
          onTap: () => AlMobarmgBranding.openWebsite(context),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              // Shrinks instead of overflowing on narrow screens / large text.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AlMobarmgLogo(height: 26),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: secondary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'AL MOBARMG',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: name,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.dark,
    required this.name,
    required this.secondary,
  });

  final bool dark;
  final Color name;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final surface = dark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF5F7FA);
    final border = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E7EB);
    final radius = BorderRadius.circular(14);

    // Capped width so it stays a signature, not a banner, on tablets / web.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => AlMobarmgBranding.openWebsite(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const AlMobarmgLogo(height: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AL MOBARMG',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: name,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Software Company',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          AlMobarmgBranding.websiteLabel,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AlMobarmgBranding.brandBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Directionality(
                    // An external-link arrow must not be mirrored in RTL.
                    textDirection: TextDirection.ltr,
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The AL MOBARMG mark, redrawn as vector geometry from the company logo so it
/// stays sharp at any size and needs no image asset.
class AlMobarmgLogo extends StatelessWidget {
  const AlMobarmgLogo({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: height * _LogoPainter.aspect,
        child: const CustomPaint(painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  // Drawing space (from the 1000px master logo), cropped to the mark.
  static const double _left = 298, _top = 256, _w = 404, _h = 366;
  static const double aspect = _w / _h;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);
    canvas.translate(-_left, -_top);

    final stroke = Paint()
      ..color = AlMobarmgBranding.brandBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Outer trace: top-left node -> quarter turn -> right stem.
    canvas.drawPath(
      Path()
        ..moveTo(330, 287)
        ..lineTo(455, 287)
        ..arcToPoint(const Offset(610, 442), radius: const Radius.circular(155))
        ..lineTo(610, 608),
      stroke,
    );
    // Middle loop: short inner tail -> around -> bottom rail to the right node.
    canvas.drawPath(
      Path()
        ..moveTo(568, 485)
        ..lineTo(568, 445)
        ..arcToPoint(
          const Offset(460, 337),
          radius: const Radius.circular(108),
          clockwise: false,
        )
        ..arcToPoint(
          const Offset(352, 445),
          radius: const Radius.circular(108),
          clockwise: false,
        )
        ..arcToPoint(
          const Offset(460, 553),
          radius: const Radius.circular(108),
          clockwise: false,
        )
        ..lineTo(668, 553),
      stroke,
    );
    // Inner curl: centre node -> around -> left stem.
    canvas.drawPath(
      Path()
        ..moveTo(465, 507)
        ..arcToPoint(const Offset(403, 445), radius: const Radius.circular(62))
        ..arcToPoint(const Offset(465, 383), radius: const Radius.circular(62))
        ..arcToPoint(const Offset(527, 445), radius: const Radius.circular(62))
        ..lineTo(527, 608),
      stroke,
    );

    // Each node: blue disc, thin white ring, navy core.
    final disc = Paint()..color = AlMobarmgBranding.brandBlue;
    final ring = Paint()..color = Colors.white;
    final dot = Paint()..color = AlMobarmgBranding.brandNavy;
    for (final c in const [
      Offset(330, 287),
      Offset(465, 507),
      Offset(668, 553),
    ]) {
      canvas.drawCircle(c, 27, disc);
      canvas.drawCircle(c, 19, ring);
      canvas.drawCircle(c, 13, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
