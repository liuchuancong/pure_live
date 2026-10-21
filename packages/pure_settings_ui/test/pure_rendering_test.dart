// The pure rendering's two contracts, pinned: a settings_ui slot that is a
// plain Text crosses into pure_uikit's own string-taking row, and anything
// else falls back to the widget row rather than being dropped; and a switch
// tile is the row itself — tapping anywhere flips it, a disabled one does not.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_settings_ui/src/pure/pure_page_bar.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_section.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_tile.dart';
import 'package:pure_settings_ui/src/pure/pure_text_slot.dart';
import 'package:pure_settings_ui/src/vendor/tiles/settings_tile.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  group('text slots', () {
    test('a Text yields its data', () {
      expect(pureTextOf(const Text('General')), 'General');
    });

    test('a Text.rich carries a span, not a string', () {
      expect(pureTextOf(const Text.rich(TextSpan(text: 'General'))), isNull);
    });

    test('anything else is not text', () {
      expect(pureTextOf(const Icon(Icons.settings)), isNull);
      expect(pureTextOf(null), isNull);
    });

    test('a present-slot list is text only when every present slot is', () {
      expect(pureSlotsAreText([const Text('a'), null, const Text('b')]), isTrue);
      expect(pureSlotsAreText([const Text('a'), const Icon(Icons.add)]), isFalse);
    });
  });

  group('a navigation tile', () {
    testWidgets('renders its texts and answers a tap', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_host(SettingsTile.navigation(
        leading: const Icon(Icons.refresh_outlined),
        title: const Text('Refresh on resume'),
        value: const Text('On'),
        onPressed: (_) => pressed = true,
      )));

      expect(find.text('Refresh on resume'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      await tester.tap(find.text('Refresh on resume'));
      expect(pressed, isTrue);
    });

    testWidgets('a widget title falls back to the widget row instead of dropping', (tester) async {
      await tester.pumpWidget(_host(SettingsTile.navigation(
        title: const Row(children: [Icon(Icons.bolt), Text('Boosted')]),
        onPressed: (_) {},
      )));

      expect(find.text('Boosted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selected reaches the row', (tester) async {
      await tester.pumpWidget(_host(_pureTile('Chosen', selected: true)));
      expect(tester.widget<ListTile>(find.byType(ListTile)).selected, isTrue);
    });
  });

  group('a switch tile', () {
    testWidgets('taps the row to flip it', (tester) async {
      bool? next;
      await tester.pumpWidget(_host(SettingsTile.switchTile(
        initialValue: false,
        onToggle: (value) => next = value,
        title: const Text('Auto refresh'),
      )));

      expect(find.byType(PureSwitch), findsOneWidget);
      await tester.tap(find.text('Auto refresh'));
      expect(next, isTrue);
    });

    testWidgets('a disabled switch is an inert row', (tester) async {
      var flipped = false;
      await tester.pumpWidget(_host(SettingsTile.switchTile(
        initialValue: false,
        onToggle: (_) => flipped = true,
        enabled: false,
        title: const Text('Locked'),
      )));

      await tester.tap(find.text('Locked'));
      expect(flipped, isFalse);
    });
  });

  testWidgets('a section frames its tiles in one card under its title', (tester) async {
    await tester.pumpWidget(_host(PureSettingsSection(
      title: const Text('General'),
      margin: EdgeInsetsDirectional.zero,
      tiles: [
        SettingsTile.navigation(title: const Text('First'), onPressed: (_) {}),
        SettingsTile.navigation(title: const Text('Second'), onPressed: (_) {}),
      ],
    )));

    expect(find.text('General'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the page bar carries the back affordance only when asked', (tester) async {
    var left = false;
    await tester.pumpWidget(_host(PurePageBar(title: const Text('Appearance'), onBack: () => left = true)));
    expect(find.byType(PureIconButton), findsOneWidget);
    await tester.tap(find.byType(PureIconButton));
    expect(left, isTrue);

    await tester.pumpWidget(_host(const PurePageBar(title: Text('Appearance'))));
    expect(find.byType(PureIconButton), findsNothing);
  });

  testWidgets('a row outside a section is divided by nothing', (tester) async {
    BuildContext? captured;
    await tester.pumpWidget(_host(Builder(
      builder: (context) {
        captured = context;
        return const SizedBox.shrink();
      },
    )));
    expect(PureSettingsRowScope.dividedOf(captured!), isFalse);
  });
}

/// A pure tile straight from its data, so [PureSettingsTile]'s own fields —
/// selected, semantics — are reachable without the split view's list scope.
Widget _pureTile(String title, {bool selected = false}) => PureSettingsTile(
  SettingsTileData(
    tileType: SettingsTileType.navigationTile,
    leading: null,
    title: Text(title),
    titleDescription: null,
    description: null,
    onPressed: null,
    onToggle: null,
    value: null,
    initialValue: false,
    activeSwitchColor: null,
    enabled: true,
    trailing: null,
    compact: false,
    titlePadding: null,
    leadingPadding: null,
    trailingPadding: null,
    descriptionPadding: null,
    titleDescriptionPadding: null,
  ),
  selected: selected,
);

Widget _host(Widget child) => PureConfigProvider(
  config: const UiConfig(language: PureDesignLanguage.material),
  child: MaterialApp(
    home: SettingsTheme(
      themeData: const SettingsThemeData(),
      platform: DevicePlatform.pure,
      child: Scaffold(body: child),
    ),
  ),
);
