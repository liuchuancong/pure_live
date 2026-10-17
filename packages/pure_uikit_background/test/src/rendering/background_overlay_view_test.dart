import 'dart:typed_data' show Uint8List;

import 'package:blur/blur.dart';
import 'package:flutter/material.dart' show MaterialApp, MemoryImage, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart';
import 'package:pure_uikit_background/src/rendering/background_overlay_view.dart';

const _scrimColor = Color(0xFF101018);

/// Matches only the package's own scrim; the host scaffold paints its own
/// `ColoredBox`es, so a bare `find.byType` would be meaningless.
Finder _scrim(Color color) => find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == color);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('BackgroundOverlayView', () {
    testWidgets('no-op when the overlay is null', (tester) async {
      await _pump(tester, const BackgroundOverlayView(overlay: null, child: SizedBox.expand()));

      expect(_scrim(_scrimColor), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('no-op when the opacity is zero', (tester) async {
      await _pump(
        tester,
        const BackgroundOverlayView(
          overlay: BackgroundOverlay(color: _scrimColor, opacity: 0),
          child: SizedBox.expand(),
        ),
      );

      expect(_scrim(_scrimColor), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('paints a flat wash and skips the blur pass at sigma 0', (tester) async {
      await _pump(
        tester,
        const BackgroundOverlayView(
          overlay: BackgroundOverlay(color: _scrimColor, opacity: 0.35),
          child: SizedBox.expand(),
        ),
      );

      expect(find.byType(Blur), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(_scrim(_scrimColor.withValues(alpha: 0.35)), findsOneWidget);
    });

    testWidgets('frosts the backdrop when the sigma is positive', (tester) async {
      await _pump(
        tester,
        const BackgroundOverlayView(
          overlay: BackgroundOverlay(color: _scrimColor, opacity: 0.25, blurSigma: 18),
          child: SizedBox.expand(),
        ),
      );

      expect(find.byType(Blur), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('PureBackground routes a frosted overlay over an image base', (tester) async {
      await _pump(
        tester,
        PureBackground(
          config: ImageBackground(
            source: ProviderImageSource(MemoryImage(Uint8List(0))),
            overlay: const BackgroundOverlay(color: _scrimColor, opacity: 0.3, blurSigma: 10),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
