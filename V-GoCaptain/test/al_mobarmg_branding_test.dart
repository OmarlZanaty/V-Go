import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_go_captain/core/branding/al_mobarmg_branding.dart';

// Renders both branding variants in the conditions they must survive: small
// and large screens, large text, RTL / LTR and light / dark. Any RenderFlex
// overflow fails the test.
void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'tablet': Size(1024, 1366),
  };

  for (final entry in sizes.entries) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final dir in [TextDirection.rtl, TextDirection.ltr]) {
        for (final brightness in [Brightness.dark, Brightness.light]) {
          testWidgets(
            '${entry.key} x$scale ${dir.name} ${brightness.name}',
            (tester) async {
              tester.view.physicalSize = entry.value;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: entry.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(
                    textDirection: dir,
                    child: const Scaffold(
                      body: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            AlMobarmgBranding.full(),
                            Spacer(),
                            AlMobarmgBranding.compact(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ));

              expect(tester.takeException(), isNull);
              expect(find.text('AL MOBARMG'), findsNWidgets(2));
              expect(find.text('almobarmg.com'), findsOneWidget);

              // Full card stays a signature, not a banner, on wide screens.
              final card = tester.getSize(find.byType(Material).last);
              expect(card.width, lessThanOrEqualTo(520));

              // The compact signature is a comfortable tap target.
              final tap = tester.getSize(find.descendant(
                of: find.byType(AlMobarmgBranding).last,
                matching: find.byType(InkWell),
              ));
              expect(tap.height, greaterThanOrEqualTo(48));
            },
          );
        }
      }
    }
  }

  testWidgets('whole block is one labelled link for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AlMobarmgBranding.full())),
    ));
    expect(
      find.bySemanticsLabel('Visit AL MOBARMG Software Company website'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
