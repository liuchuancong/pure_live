import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/music/controller/music_hotkeys.dart';

void main() {
  group('MusicHotkeyCombo', () {
    test('parses, normalizes modifier order and case', () {
      final combo = MusicHotkeyCombo.parse('Alt+MOD+ArrowLeft')!;
      expect(combo.serialize(), 'mod+alt+arrowleft');
      expect(MusicHotkeyCombo.parse('mod+alt+arrowleft')!.serialize(), 'mod+alt+arrowleft');
    });

    test('rejects empty and ambiguous combos', () {
      expect(MusicHotkeyCombo.parse(''), isNull);
      expect(MusicHotkeyCombo.parse('alt+shift'), isNull);
      expect(MusicHotkeyCombo.parse('a+b'), isNull);
    });

    test('display names arrows, platform key and capitalization', () {
      expect(MusicHotkeyCombo.parse('mod+alt+arrowleft')!.display(), 'Ctrl + Alt + ←');
      expect(MusicHotkeyCombo.parse('mod+alt+arrowleft')!.display(appleMod: true), 'Command + Alt + ←');
      expect(MusicHotkeyCombo.parse('mod+f5')!.display(), 'Ctrl + F5');
      expect(MusicHotkeyCombo.parse('alt+0')!.display(), 'Alt + 0');
    });

    test('maps keys to logical keys for accelerators', () {
      final arrow = MusicHotkeyCombo.parse('mod+alt+arrowleft')!;
      final activator = arrow.activator;
      expect(activator.trigger, LogicalKeyboardKey.arrowLeft);
      expect(activator.control, isTrue);
      expect(activator.alt, isTrue);

      final f5 = MusicHotkeyCombo.parse('mod+alt+f5')!;
      expect(f5.activator.trigger, LogicalKeyboardKey.f5);

      final digit = MusicHotkeyCombo.parse('mod+alt+0')!;
      expect(digit.activator.trigger, LogicalKeyboardKey.digit0);
    });

    test('equal combos compare equal regardless of input case', () {
      expect(MusicHotkeyCombo.parse('MOD+ALT+ArrowLeft'), MusicHotkeyCombo.parse('mod+alt+arrowleft'));
    });
  });

  group('MusicHotkeyConfig', () {
    test('defaults follow the reference global table', () {
      const standard = MusicHotkeyConfig.standard;
      expect(standard[MusicHotkeyAction.togglePlay]!.serialize(), 'mod+alt+f5');
      expect(standard[MusicHotkeyAction.prev]!.serialize(), 'mod+alt+arrowleft');
      expect(standard[MusicHotkeyAction.next]!.serialize(), 'mod+alt+arrowright');
      expect(standard[MusicHotkeyAction.volumeUp]!.serialize(), 'mod+alt+arrowup');
      expect(standard[MusicHotkeyAction.volumeDown]!.serialize(), 'mod+alt+arrowdown');
      expect(standard.containsKey(MusicHotkeyAction.musicDislike), isFalse);
    });

    test('assigning a held combo steals it from the other action', () {
      const config = MusicHotkeyConfig(enabled: true, globalEnabled: false, assignments: MusicHotkeyConfig.standard);
      final moved = config.withAssignment(
        MusicHotkeyAction.volumeMute,
        MusicHotkeyCombo.parse('mod+alt+arrowup'),
      );
      expect(moved.assignments[MusicHotkeyAction.volumeMute]!.serialize(), 'mod+alt+arrowup');
      expect(moved.assignments.containsKey(MusicHotkeyAction.volumeUp), isFalse);
    });

    test('clearing an assignment removes it without touching others', () {
      const config = MusicHotkeyConfig(enabled: true, globalEnabled: false, assignments: MusicHotkeyConfig.standard);
      final cleared = config.withAssignment(MusicHotkeyAction.next, null);
      expect(cleared.assignments.containsKey(MusicHotkeyAction.next), isFalse);
      expect(cleared.assignments.containsKey(MusicHotkeyAction.prev), isTrue);
    });

    test('the global flag survives assignment edits, the reference default is off', () {
      const config = MusicHotkeyConfig(enabled: true, globalEnabled: true, assignments: MusicHotkeyConfig.standard);
      final edited = config.withAssignment(MusicHotkeyAction.seekForward, MusicHotkeyCombo.parse('mod+alt+arrowright'));
      expect(edited.globalEnabled, isTrue);
      expect(edited.assignments[MusicHotkeyAction.seekForward]!.serialize(), 'mod+alt+arrowright');
      const plain = MusicHotkeyConfig(enabled: true, globalEnabled: false, assignments: {});
      expect(plain.globalEnabled, isFalse);
    });
  });
}
