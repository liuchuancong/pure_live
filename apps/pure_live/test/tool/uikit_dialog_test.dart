// A visual review harness for the modal: the same dialog, opened in each design
// language, written out as a PNG so the surface and its action row can be
// inspected side by side. Regenerate with:
//
//   flutter test test/tool/uikit_dialog_test.dart --update-goldens
//
// The images land in test/tool/dialog/<language>.png. Review artifacts, not CI
// assertions.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  setUpAll(loadFonts);
  for (final language in PureDesignLanguage.values) {
    testWidgets('dialog ${language.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(720, 620);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: PureConfigProvider(
            config: UiConfig(language: language, fontFamily: 'packages/forui/Inter'),
            child: PureApp(
              routerConfig: GoRouter(
                routes: [GoRoute(path: '/', builder: (context, state) => const _Page())],
              ),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: appSupportedLocales,
              builder: (context, appChild) => TranslationProvider(child: appChild!),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
      // The dialog is opened from inside the route so its actions resolve against
      // the dialog's own context, exactly as a page would raise one.
      await tester.tap(find.byKey(const ValueKey('open-dialog')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
      await expectLater(find.byType(Overlay).first, matchesGoldenFile('dialog/${language.name}.png'));
    });
  }
}

/// The page behind the modal: one button that raises the dialog under test.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Scaffold(
      body: Center(
        child: PureButton(
          key: const ValueKey('open-dialog'),
          label: 'Open',
          onPressed: () => showPureDialog<void>(
            context: context,
            title: 'Clear the cache?',
            // Long on purpose: a body the surface cannot scroll pushes this
            // block, and the action row, off the screen. The lines name the
            // theme's own body role — a bare `Text` inherits no family here and
            // renders as a row of boxes whatever the language.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 14; i++)
                  Text(
                    'Line $i — the body has to stay inside the window and the actions stay reachable.',
                    style: theme.text.body.copyWith(color: theme.colors.text),
                  ),
              ],
            ),
            actions: (dialogContext) => [
              PureButton(
                label: 'Cancel',
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              PureButton(
                key: const ValueKey('dialog-confirm'),
                label: 'Clear',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// See `uikit_showcase_test.dart`: widget tests serve no fonts unless they are
/// loaded, and a missing icon family shows up as a solid box.
Future<void> loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  Uint8List? textFace;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final family = entry['family']! as String;
    for (final font in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      try {
        final data = await rootBundle.load(font['asset']! as String);
        final bytes = data.buffer.asUint8List();
        await ui.loadFontFromList(bytes, fontFamily: family);
        if (family.endsWith('/Inter') && !(font['asset']! as String).contains('Italic')) {
          textFace = bytes;
        }
      } on Exception catch (_) {
        // A family the bundle cannot serve is not fatal for the review sheet.
      }
    }
  }
  if (textFace case final face?) {
    for (final systemName in const [
      '.SF Pro Text',
      '.SF Pro Display',
      '.AppleSystemUIFont',
      'Roboto',
      'Segoe UI',
      'Segoe UI Variable Text',
      'Segoe UI Variable Display',
      'Ubuntu',
      'Inter',
    ]) {
      await ui.loadFontFromList(face, fontFamily: systemName);
    }
  }
}
