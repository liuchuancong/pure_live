// Throwaway probe: close-up renders of the suspect controls, for pixel-level
// review. Delete when the audit is done.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:convert' show jsonDecode;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final family = entry['family']! as String;
    for (final font in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      try {
        final data = await rootBundle.load(font['asset']! as String);
        await ui.loadFontFromList(data.buffer.asUint8List(), fontFamily: family);
      } on Exception catch (_) {}
    }
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('fluent close-up', (tester) async {
    await _pump(tester, PureDesignLanguage.fluent, const _Closeup());
  });
  testWidgets('cupertino close-up', (tester) async {
    await _pump(tester, PureDesignLanguage.cupertino, const _Closeup());
  });
  testWidgets('glass close-up', (tester) async {
    await _pump(tester, PureDesignLanguage.glass, const _Closeup());
  });
  testWidgets('wind close-up', (tester) async {
    await _pump(tester, PureDesignLanguage.wind, const _Closeup());
  });
  testWidgets('neumorphic close-up', (tester) async {
    await _pump(tester, PureDesignLanguage.neumorphic, const _Closeup());
  });
}

class _Closeup extends StatelessWidget {
  const _Closeup();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Material(
        key: const ValueKey('closeup-root'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureButton(label: 'Primary', icon: Icons.add, onPressed: () {}),
                  const SizedBox(width: 8),
                  PureButton(label: 'Secondary', variant: ButtonVariant.secondary, onPressed: () {}),
                  const SizedBox(width: 8),
                  PureButton(label: 'Ghost', variant: ButtonVariant.ghost, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureButton(label: 'Small', size: ControlSize.sm, onPressed: () {}),
                  const SizedBox(width: 8),
                  PureButton(label: 'Medium', onPressed: () {}),
                  const SizedBox(width: 8),
                  PureButton(label: 'Large', size: ControlSize.lg, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureButton(label: 'Loading', loading: true, onPressed: () {}),
                  const SizedBox(width: 8),
                  const PureButton(label: 'Disabled'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureIconButton(icon: Icons.search_rounded, tooltip: 'Search', onPressed: () {}),
                  const SizedBox(width: 8),
                  PureIconButton(icon: Icons.star_rounded, tooltip: 'Fav', selected: true, onPressed: () {}),
                  const SizedBox(width: 8),
                  PureIconButton(icon: Icons.close_rounded, tooltip: 'Close', size: ControlSize.sm, onPressed: () {}),
                  const SizedBox(width: 8),
                  PureIconButton(icon: Icons.add_rounded, tooltip: 'Add', size: ControlSize.lg, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 12),
              const PureTextField(placeholder: 'Type here…', prefix: Icon(Icons.search_rounded, size: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureSwitch(value: true, onChanged: (_) {}),
                  const SizedBox(width: 12),
                  PureSwitch(value: false, onChanged: (_) {}),
                  const SizedBox(width: 12),
                  PureCheckbox(value: true, onChanged: (_) {}, label: 'Checked'),
                ],
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureBadge(count: 5),
                  SizedBox(width: 12),
                  PureBadge(label: 'New'),
                  SizedBox(width: 12),
                  PureBadge(dot: true, child: PureAvatar(name: 'A', size: 36)),
                ],
              ),
              const SizedBox(height: 12),
              PureTabs(
                tabs: const [PureTab(label: 'Home', icon: Icons.home_outlined), PureTab(label: 'Settings', icon: Icons.settings_outlined)],
                index: 0,
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PureNavBar(
                  items: const [
                    PureNavBarItem(label: 'Home', icon: Icons.home_outlined),
                    PureNavBarItem(label: 'Pulse', icon: Icons.local_fire_department_outlined),
                    PureNavBarItem(label: 'Me', icon: Icons.person_outline),
                  ],
                  index: 0,
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, PureDesignLanguage language, Widget child) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(760, 640);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: PureConfigProvider(
        config: UiConfig(language: language),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (context, state) => child)],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          builder: (context, appChild) => TranslationProvider(child: appChild!),
        ),
      ),
    ),
  );
  for (var attempt = 0; attempt < 6; attempt++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
  await expectLater(
    find.byKey(const ValueKey('closeup-root')),
    matchesGoldenFile('closeup/${language.name}.png'),
  );
}
