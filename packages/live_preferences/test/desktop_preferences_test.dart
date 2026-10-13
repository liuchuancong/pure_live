import 'package:live_preferences/live_preferences.dart';
import 'package:live_shell/live_shell.dart' show CloseAction, ShellSettings;
import 'package:test/test.dart';

/// The persisted shape of the desktop group, pinned on purpose.
///
/// These are not tests of behaviour but of the **stored document**, which outlives
/// the build that wrote it. A user who installs a new version and then rolls back
/// hands the older binary a file it has never seen, and the only interesting
/// failure there is the one that stops the app starting at all — which is exactly
/// what an unrecognized enum value does by default in `json_serializable`.
void main() {
  group('the close action on disk', () {
    test('the default is written as the name shipped builds already use', () {
      const preferences = DesktopPreferences();

      expect(preferences.toJson()['closeAction'], 'hideToTray');
    });

    test('every value round-trips through its name', () {
      for (final action in CloseAction.values) {
        final restored = DesktopPreferences.fromJson({'closeAction': action.name});

        expect(restored.closeAction, action, reason: action.name);
      }
    });

    test('a value from a newer build is read as the default, not thrown', () {
      // Rollback is the case: the document contains `askTheViewer`, which this
      // build has never heard of. Failing to parse the settings group means the
      // app cannot start, so a saved preference must never be able to say that.
      final restored = DesktopPreferences.fromJson({'closeAction': 'askTheViewer'});

      expect(restored.closeAction, CloseAction.hideToTray);
    });

    test('an absent or null value is the default', () {
      expect(DesktopPreferences.fromJson(const {}).closeAction, CloseAction.hideToTray);
      expect(DesktopPreferences.fromJson({'closeAction': null}).closeAction, CloseAction.hideToTray);
    });

    test('a value of the wrong type costs a reset, not a crash', () {
      // The deliberate trade: a document with `7` where a name belongs is corrupt,
      // and the alternative — reporting it — means the settings group fails to
      // load, which for a desktop app means no window at all. One field silently
      // returning to its default is the price of always starting.
      final restored = DesktopPreferences.fromJson({'closeAction': 7});

      expect(restored.closeAction, CloseAction.hideToTray);
      expect(
        restored.startHidden,
        isFalse,
        reason: 'the rest of the document still loads; one bad field is not a bad file',
      );
    });
  });

  group('the rest of the group', () {
    test('a duration survives as microseconds', () {
      const preferences = DesktopPreferences(idleReclaimAfter: Duration(minutes: 5));

      final restored = DesktopPreferences.fromJson(Map<String, Object?>.from(preferences.toJson()));

      expect(restored.idleReclaimAfter, const Duration(minutes: 5));
    });

    test('a partial document from an older build keeps its fields and defaults the rest', () {
      // The realistic upgrade: the file has two keys because it predates this
      // group having ten.
      final restored = DesktopPreferences.fromJson({'rememberWindowBounds': false, 'effects': false});

      expect(restored.rememberWindowBounds, isFalse);
      expect(restored.effects, isFalse);
      expect(restored.hardwareAcceleration, isTrue, reason: 'untouched fields keep their shipping default');
      expect(restored.reclaimWhenIdle, isFalse);
    });
  });

  group('projection into shell configuration', () {
    test('the shipping defaults project to the defaults of the shell itself', () {
      const preferences = DesktopPreferences();
      const expected = ShellSettings();

      final settings = preferences.shellSettings;

      expect(settings.closeAction, expected.closeAction);
      expect(settings.trayEnabled, expected.trayEnabled);
      expect(settings.rememberBounds, expected.rememberBounds);
      expect(settings.startHidden, expected.startHidden);
      expect(settings.reclaimWhenIdle, expected.reclaimWhenIdle);
      expect(settings.idleReclaimAfter, expected.idleReclaimAfter);
    });

    test('each switch reaches the field the shell actually asks about', () {
      const flipped = DesktopPreferences(
        closeAction: CloseAction.quit,
        showTrayIcon: false,
        rememberWindowBounds: false,
        startHidden: true,
        reclaimWhenIdle: true,
        idleReclaimAfter: Duration(minutes: 5),
      );

      final settings = flipped.shellSettings;

      expect(settings.closeAction, CloseAction.quit);
      expect(settings.trayEnabled, isFalse);
      expect(settings.rememberBounds, isFalse);
      expect(settings.startHidden, isTrue);
      expect(settings.reclaimWhenIdle, isTrue);
      expect(settings.idleReclaimAfter, const Duration(minutes: 5));
    });

    test('the polling interval is not a stored setting', () {
      // Nothing in the document can change it, so the projected value is the
      // shell's own default however the group is configured.
      const preferences = DesktopPreferences(reclaimWhenIdle: true, idleReclaimAfter: Duration(minutes: 9));

      expect(preferences.shellSettings.idlePollInterval, const ShellSettings().idlePollInterval);
    });

    test('either escape hatch lands in the fallbacks, and either one off forces an opaque surface', () {
      const both = DesktopPreferences(effects: false, hardwareAcceleration: false);

      expect(both.renderFallbacks.effects, isFalse);
      expect(both.renderFallbacks.hardwareAcceleration, isFalse);
      expect(both.renderFallbacks.needsOpaqueSurface, isTrue);
      expect(const DesktopPreferences().renderFallbacks.needsOpaqueSurface, isFalse);
    });

    test('no persisted field is left without a named consumer', () {
      // Adding a setting nobody reads is the failure this table exists to catch:
      // the viewer changes it, nothing happens, and no error is ever produced.
      final documented = desktopFieldConsumers.keys.toSet();
      final persisted = const DesktopPreferences().toJson().keys.toSet();

      expect(persisted, documented, reason: 'the document and the consumer table have drifted apart');
    });
  });
}
