// A visual review harness: every Pure* control, rendered by each design
// language, written out as a PNG golden so the nine renderings can be
// inspected side by side. Regenerate with:
//
//   flutter test test/tool/uikit_showcase_test.dart --update-goldens
//
// The images land in test/tool/showcase/<language>.png. They are review
// artifacts, not CI assertions — nothing here runs in the normal suite unless
// it is run by name.
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
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final language in PureDesignLanguage.values) {
    testWidgets('showcase ${language.name}', (tester) async {
      await _pump(tester, language: language);
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byKey(const ValueKey('showcase-root')),
        matchesGoldenFile('showcase/${language.name}.png'),
      );
    });
  }
}

/// The retry callback the error state asks for; the sheet never presses it.
void _noop() {}

/// The review sheet: the whole control set in one column.
class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Material(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buttons', style: theme.text.title),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureButton(label: 'Primary', icon: Icons.add, onPressed: () {}),
                  PureButton(label: 'Secondary', icon: Icons.edit, variant: ButtonVariant.secondary, onPressed: () {}),
                  PureButton(label: 'Danger', icon: Icons.delete, variant: ButtonVariant.danger, onPressed: () {}),
                  PureButton(label: 'Ghost', icon: Icons.more_horiz, variant: ButtonVariant.ghost, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PureButton(label: 'Small', size: ControlSize.sm, onPressed: () {}),
                  PureButton(label: 'Medium', onPressed: () {}),
                  PureButton(label: 'Large', size: ControlSize.lg, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PureButton(label: 'Loading', loading: true, onPressed: () {}),
                  const PureButton(label: 'Disabled'),
                  PureButton(label: 'Expand', expand: true, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 16),
              Text('Icon buttons', style: theme.text.title),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PureIconButton(icon: Icons.search_rounded, tooltip: 'Search', onPressed: () {}),
                  PureIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    variant: ButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  PureIconButton(icon: Icons.star_rounded, tooltip: 'Favorite', selected: true, onPressed: () {}),
                  PureIconButton(icon: Icons.close_rounded, tooltip: 'Close', size: ControlSize.sm, onPressed: () {}),
                  PureIconButton(icon: Icons.add_rounded, tooltip: 'Add', size: ControlSize.lg, onPressed: () {}),
                  const PureIconButton(icon: Icons.bolt_outlined, tooltip: 'Off'),
                ],
              ),
              const SizedBox(height: 16),
              Text('Fields and choices', style: theme.text.title),
              const SizedBox(height: 8),
              const PureTextField(placeholder: 'Type here…', prefix: Icon(Icons.search_rounded, size: 18)),
              const SizedBox(height: 8),
              Row(
                children: [
                  PureSwitch(value: true, onChanged: (_) {}),
                  const SizedBox(width: 12),
                  PureSwitch(value: false, onChanged: (_) {}),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 170,
                    child: PureCheckbox(value: true, onChanged: (_) {}, label: 'Checked'),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 190,
                    child: PureCheckbox(value: false, onChanged: (_) {}, label: 'Unchecked'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PureSegmented(labels: const ['All', 'Following', 'Popular'], index: 1, onChanged: (_) {}),
              const SizedBox(height: 8),
              PureSelect<int>(items: const [1, 2, 3], itemLabel: (i) => 'Option $i', value: 2, onChanged: (_) {}),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 260, child: PureNumberStepper(value: 3, onChanged: null)),
                  const SizedBox(width: 12),
                  Expanded(child: PureSlider(value: 0.4, onChanged: (_) {})),
                ],
              ),
              const SizedBox(height: 16),
              Text('Tabs and progress', style: theme.text.title),
              const SizedBox(height: 8),
              PureTabs(
                tabs: const [
                  PureTab(label: 'Home', icon: Icons.home_outlined),
                  PureTab(label: 'Following', icon: Icons.star_outline),
                  PureTab(label: 'Settings', icon: Icons.settings_outlined),
                ],
                index: 1,
                onChanged: (_) {},
              ),
              const SizedBox(height: 8),
              const PureProgress(value: 0.6),
              const SizedBox(height: 8),
              const Row(
                children: [
                  PureSpinner(),
                  SizedBox(width: 12),
                  PureBadge(count: 5, child: PureAvatar(name: 'Liu', size: 36)),
                  SizedBox(width: 16),
                  PureBadge(
                    label: 'New',
                    child: PureAvatar(name: 'AB', size: 36, shape: PureAvatarShape.rounded),
                  ),
                  // The tag form, which is where the libraries with their own
                  // badge component get to draw it.
                  SizedBox(width: 16),
                  PureBadge(label: 'Beta'),
                ],
              ),
              const SizedBox(height: 16),
              Text('Cards and rows', style: theme.text.title),
              const SizedBox(height: 8),
              PureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PureListRow(
                      leading: const Icon(Icons.notifications_outlined),
                      title: 'Notifications',
                      subtitle: 'Alerts and focus mode',
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                    PureListRow(
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: 'Dark mode',
                      trailing: PureSwitch(value: true, onChanged: (_) {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Settings list', style: theme.text.title),
              const SizedBox(height: 8),
              SizedBox(
                // SettingsList scrolls itself; bound it inside this sheet.
                height: 260,
                child: SettingsList(
                  sections: [
                    SettingsSection(
                      title: const Text('Theme'),
                      tiles: [
                        SettingsTile.navigation(
                          leading: const Icon(Icons.dark_mode_outlined),
                          title: const Text('Theme mode'),
                          description: const Text('Follow the system, light or dark'),
                          onPressed: (_) {},
                        ),
                        SettingsTile.navigation(
                          leading: const Icon(Icons.colorize_outlined),
                          title: const Text('Accent color'),
                          value: const Text('Blue'),
                          onPressed: (_) {},
                        ),
                        SettingsTile.switchTile(
                          leading: const Icon(Icons.contrast_outlined),
                          title: const Text('Pure black'),
                          description: const Text('Good for OLED screens'),
                          initialValue: true,
                          onToggle: (_) {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Navigation bar', style: theme.text.title),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PureNavBar(
                  items: const [
                    PureNavBarItem(label: 'Home', icon: Icons.home_outlined),
                    PureNavBarItem(label: 'Pulse', icon: Icons.local_fire_department_outlined),
                    PureNavBarItem(label: 'Messages', icon: Icons.chat_bubble_outline),
                    PureNavBarItem(label: 'Me', icon: Icons.person_outline),
                  ],
                  index: 0,
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 24),
              Text('States', style: theme.text.title),
              const SizedBox(height: 8),
              // The three full-view states are the only place the state glyphs
              // are drawn, and those glyphs come from a font the app has to
              // depend on — a missing `cupertino_icons` showed up here as a
              // solid box and nowhere else on the sheet.
              const PureError(message: 'The stream could not be reached', onRetry: _noop),
              const SizedBox(height: 8),
              const PureEmpty(title: 'Nothing followed yet', message: 'Follow a channel to fill this page'),
              const SizedBox(height: 8),
              const PureLoading(message: 'Loading'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget tests serve no fonts by default, so every glyph would render as a
/// box. Loads what the bundle's FontManifest declares (MaterialIcons, Ubuntu,
/// Inter, CupertinoIcons, each library's icon font) the way golden_toolkit does.
/// CJK is not bundled by the app, so the sheet's labels are English.
///
/// **Read a box on this sheet by which family it belongs to.** A whole page of
/// boxes means the loader did not run; one box where a tick, a chevron or a
/// status mark should be means the icon font's *package* is missing from the
/// dependency graph — `flutter/cupertino` ships the `CupertinoIcons` constants
/// but not the face, so nothing renders the glyph and the golden shows a solid
/// square instead. That is a product defect the sheet can hide for months, and
/// changing a pubspec does not rebuild `build/unit_test_assets` on its own:
/// touch it, rerun, then grep the manifest for the family.
///
/// Then registers that Latin text face a second time under the **system** family
/// names the host libraries ask for — `.SF Pro Text` for Cupertino,
/// `Segoe UI Variable` for Fluent, `Roboto` for Material and so on — and names it
/// on the sheet's `UiConfig` as well. Both are needed, and which one is missing
/// tells you where a box came from: the section headers render off the theme's
/// own family, the fields, segmented control and tabs only came legible once the
/// system names were aliased, and what is *still* a box (button labels, list
/// rows, navigation labels, the settings rows) is text a library widget styles
/// for itself, which no amount of font registration in a test can route through
/// the app's font preference. That last part is a product gap, not a harness one.
Future<void> loadAppFonts() async {
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
        // The manifest lists the italic and the regular face under one family,
        // and a second registration replaces the first — taking whichever came
        // last rendered the whole sheet in italic. The regular face is the alias.
        if (family.endsWith('/Inter') && !(font['asset']! as String).contains('Italic')) {
          textFace = bytes;
        }
      } on Exception catch (_) {
        // A family the bundle cannot serve (an app font path) is not fatal
        // for the review sheet.
      }
    }
  }
  if (textFace == null) {
    return;
  }
  for (final systemName in _systemTextFamilies) {
    await ui.loadFontFromList(textFace, fontFamily: systemName);
  }
}

/// The family names the host libraries hand to the text engine, none of which a
/// test bundle serves.
const List<String> _systemTextFamilies = [
  '.SF Pro Text',
  '.SF Pro Display',
  '.AppleSystemUIFont',
  'Roboto',
  'Segoe UI',
  'Segoe UI Variable Text',
  'Segoe UI Variable Display',
  'Ubuntu',
  'Inter',
];

Future<void> _pump(WidgetTester tester, {required PureDesignLanguage language}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 2600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: PureConfigProvider(
        config: UiConfig(language: language, fontFamily: 'packages/forui/Inter'),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const SizedBox(key: ValueKey('showcase-root'), child: _Showcase()),
              ),
            ],
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
}
