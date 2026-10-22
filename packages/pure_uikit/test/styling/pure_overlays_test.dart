import 'dart:ui' show SemanticsRole;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key each of the three surfaces hangs its plate on: the language
/// whose shape a surface is drawing is addressable in tests and diagnostics.
Key _dialogBranch(PureDesignLanguage language) => ValueKey('PureDialog.${language.name}');
Key _toastBranch(PureDesignLanguage language) => ValueKey('PureToast.${language.name}');
Key _tipBranch(PureDesignLanguage language) => ValueKey('PureTooltip.${language.name}');

/// The dialog's action area, and the two shapes it can take: a row of buttons,
/// or the iOS alert's stacked band.
final Finder _actions = find.byKey(const Key('PureDialog.actions'));
final Finder _buttonRow = find.byKey(const Key('PureDialog.buttonRow'));
final Finder _buttonBand = find.byKey(const Key('PureDialog.buttonBand'));

/// WinUI's accent bar before the title — the mark fluent alone draws — and the
/// hairline that rules a header band off the body, which Yaru and wind draw.
final Finder _accentBar = find.byKey(const Key('PureDialog.accentBar'));
final Finder _headerRule = find.byKey(const Key('PureDialog.headerRule'));

/// The words every case in here raises a surface with.
const String _title = 'Hold on';
const String _body = 'The page you are leaving has unsaved work.';
const String _message = 'Saved to the library';
const String _hint = 'Rename this';

/// The default test window is 800x600; anything past that bottom edge has left
/// the screen the user is looking at.
const double _screenBottom = 600;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  bool animations = true,
  Brightness brightness = Brightness.light,
  Alignment alignment = Alignment.center,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        animations: animations,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Align(alignment: alignment, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page that raises a dialog: one control that opens it, the answer it hands
/// back recorded in [results].
Future<void> _pumpDialog(
  WidgetTester tester, {
  PureDesignLanguage language = PureDesignLanguage.material,
  Brightness brightness = Brightness.light,
  String title = _title,
  int lines = 1,
  bool dismissible = true,
  double maxWidth = 420,
  int actionCount = 2,
  List<Object?>? results,
}) async {
  await _pump(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final answer = await showPureDialog<Object?>(
            context: context,
            title: title,
            maxWidth: maxWidth,
            dismissible: dismissible,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (var i = 0; i < lines; i++) Text('Line $i — $_body')],
            ),
            actions: actionCount == 0
                ? null
                : (dialogContext) => [
                    TextButton(
                      key: const ValueKey('refuse'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    if (actionCount > 1)
                      TextButton(
                        key: const ValueKey('agree'),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Confirm'),
                      ),
                  ],
          );
          results?.add(answer);
        },
        child: const Text('open'),
      ),
    ),
    language: language,
    brightness: brightness,
  );
}

/// Raises the dialog and settles with the card fully open.
Future<void> _raise(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Lifts the dialog again, so one language's card never leaks into the next.
Future<void> _drop(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

/// The page that fires a toast. A control sits where the plate lands, so a test
/// can prove the plate never answers a tap meant for the page.
Future<void> _pumpToast(
  WidgetTester tester, {
  PureDesignLanguage language = PureDesignLanguage.material,
  PureToastType type = PureToastType.info,
  IconData? icon,
  Color? accent,
  Duration duration = const Duration(milliseconds: 1200),
  String message = _message,
  VoidCallback? onUnder,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: TextButton(
                    key: const ValueKey('under'),
                    onPressed: onUnder ?? () {},
                    child: const Text('press me'),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        PureToast.show(context, message, type: type, icon: icon, accent: accent, duration: duration),
                    child: const Text('show'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fire(WidgetTester tester) async {
  await tester.tap(find.text('show'));
  // One frame, never a settle: `pumpAndSettle` advances the fake clock by 100ms
  // a frame, which would spend a short message's whole life before it is
  // even looked at.
  await tester.pump();
}

/// Lets the message live out its life, so the plate leaves with it.
Future<void> _expire(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pumpAndSettle();
}

/// One hovering pointer. The renderer's mouse tracker keeps one live pointer per
/// device kind and asserts when a second is added while one is up, so a case
/// that hovers repeatedly has to detach each pointer before it makes the next.
class _Hover {
  /// A hovering pointer.
  new(this._gesture);

  final TestGesture _gesture;
  bool _detached = false;

  /// Moves the pointer, and with it the hover.
  Future<void> moveTo(Offset at) => _gesture.moveTo(at);

  /// Takes the pointer out of the scene. Idempotent, so a test that detached it
  /// and the teardown that guards a failed one never remove it twice.
  Future<void> detach() async {
    if (_detached) {
      return;
    }
    _detached = true;
    await _gesture.removePointer();
  }
}

/// Rests the pointer on [at] long enough for a hover tooltip to drop, and hands
/// the pointer back so the caller can lift it again.
Future<_Hover> _hover(WidgetTester tester, Offset at, {Duration? wait}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: at);
  final pointer = _Hover(gesture);
  addTearDown(pointer.detach);
  await tester.pump();
  await tester.pump(wait ?? const Duration(milliseconds: 600));
  // The wait is over: the entry exists, and this frame is the one that builds it.
  await tester.pump();
  await tester.pumpAndSettle();
  return pointer;
}

/// The trigger a tooltip is dropped from, padded so a hover and a long press
/// both have an honest target to land on.
Widget _tip({Duration wait = const Duration(milliseconds: 400)}) => PureTooltip(
  message: _hint,
  waitDuration: wait,
  child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.edit)),
);

Semantics _semanticsOf(WidgetTester tester, Finder surface) =>
    tester.widget<Semantics>(find.descendant(of: surface, matching: find.byType(Semantics)).first);

/// The semantics node a keyed surface wears. The toast plate, the tooltip bubble
/// and the tooltip trigger carry their key on the node itself, so the read is
/// direct rather than whatever node a descendant walk reaches first.
Semantics _semanticsAt(WidgetTester tester, Key key) => tester.widget<Semantics>(find.byKey(key));

void main() {
  group('dialog', () {
    testWidgets('every design language raises its own card', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpDialog(tester, language: language);
        await _raise(tester);

        expect(tester.takeException(), isNull, reason: '$language failed to build a dialog');
        expect(find.byKey(_dialogBranch(language)), findsOneWidget, reason: '$language lost its card');
        expect(find.text(_title), findsOneWidget, reason: '$language dropped its title');
        expect(find.text('Line 0 — $_body'), findsOneWidget, reason: '$language dropped its body');
        expect(find.text('Confirm'), findsOneWidget, reason: '$language dropped its answers');

        await _drop(tester);
        expect(find.byKey(_dialogBranch(language)), findsNothing, reason: '$language would not dismiss');
      }
    });

    testWidgets('the nine cards differ in the marks their language draws', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpDialog(tester, language: language);
        await _raise(tester);

        switch (language) {
          // WinUI's ContentDialog is the only one with the accent bar standing in
          // front of its title.
          case PureDesignLanguage.fluent:
            expect(_accentBar, findsOneWidget, reason: 'fluent lost its accent bar');
            expect(_headerRule, findsNothing);
            expect(_buttonRow, findsOneWidget);
            expect(_buttonBand, findsNothing);
          // Ubuntu's dialog and the wind paneled card rule a header band off the
          // body; Ubuntu is also the only one whose answers are equal cells.
          case PureDesignLanguage.yaru:
          case PureDesignLanguage.wind:
            expect(_headerRule, findsOneWidget, reason: '$language lost its header rule');
            expect(_accentBar, findsNothing);
            expect(_buttonRow, findsOneWidget);
          // The iOS alert stacks its answers in a banded footer, not a row.
          case PureDesignLanguage.cupertino:
            expect(_buttonBand, findsOneWidget, reason: 'the iOS alert does not stack its answers');
            expect(_buttonRow, findsNothing, reason: 'the iOS alert drew a button row');
            expect(_accentBar, findsNothing);
            expect(_headerRule, findsNothing);
          case PureDesignLanguage.material:
          case PureDesignLanguage.macos:
          case PureDesignLanguage.forui:
          case PureDesignLanguage.glass:
          case PureDesignLanguage.neumorphic:
            expect(_accentBar, findsNothing, reason: "$language borrowed Windows's mark");
            expect(_headerRule, findsNothing, reason: "$language borrowed Ubuntu's mark");
            expect(_buttonRow, findsOneWidget, reason: '$language lost its button row');
            expect(_buttonBand, findsNothing);
        }

        await _drop(tester);
      }
    });

    testWidgets('the dialog hands back the value its action pops', (tester) async {
      final results = <Object?>[];
      await _pumpDialog(tester, results: results);
      await _raise(tester);

      await tester.tap(find.byKey(const ValueKey('agree')));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(find.byKey(_dialogBranch(PureDesignLanguage.material)), findsNothing);
    });

    testWidgets('the first answer hands back its own value', (tester) async {
      final results = <Object?>[];
      await _pumpDialog(tester, results: results);
      await _raise(tester);

      await tester.tap(find.byKey(const ValueKey('refuse')));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('a tap on the scrim dismisses with null', (tester) async {
      final results = <Object?>[];
      await _pumpDialog(tester, results: results);
      await _raise(tester);

      await _drop(tester);

      expect(results, [null]);
      expect(find.text(_title), findsNothing);
    });

    testWidgets('Escape dismisses a dialog that lets itself be dismissed', (tester) async {
      final results = <Object?>[];
      await _pumpDialog(tester, results: results);
      await _raise(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.text(_title), findsNothing);
    });

    testWidgets('a confirmation that must not be waved away answers neither scrim nor Escape', (tester) async {
      final results = <Object?>[];
      await _pumpDialog(tester, dismissible: false, results: results);
      await _raise(tester);

      await _drop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_dialogBranch(PureDesignLanguage.material)), findsOneWidget);
      expect(results, isEmpty);

      await tester.tap(find.byKey(const ValueKey('agree')));
      await tester.pumpAndSettle();
      expect(results, [true]);
    });

    testWidgets('a dialog with no answers is a message alone', (tester) async {
      await _pumpDialog(tester, actionCount: 0);
      await _raise(tester);

      expect(find.byKey(_dialogBranch(PureDesignLanguage.material)), findsOneWidget);
      expect(_actions, findsNothing);
      expect(tester.takeException(), isNull);

      await _drop(tester);
    });

    testWidgets('the card reads as an alert dialog named by its title', (tester) async {
      for (final language in [
        PureDesignLanguage.material,
        PureDesignLanguage.cupertino,
        PureDesignLanguage.fluent,
        PureDesignLanguage.glass,
      ]) {
        await _pumpDialog(tester, language: language);
        await _raise(tester);

        final node = _semanticsOf(tester, find.byKey(_dialogBranch(language))).properties;
        expect(node.role, SemanticsRole.alertDialog, reason: '$language lost the dialog role');
        expect(node.label, _title, reason: '$language lost the name a reader hears');

        await _drop(tester);
      }
    });

    testWidgets('a body taller than the window scrolls and keeps its answers reachable', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpDialog(tester, language: language, lines: 40);
        await _raise(tester);

        expect(tester.takeException(), isNull, reason: '$language overflowed on a long body');
        final card = tester.getRect(find.byKey(_dialogBranch(language)));
        expect(card.bottom, lessThanOrEqualTo(_screenBottom), reason: '$language pushed its card off the screen');
        expect(
          tester.getRect(find.byKey(const ValueKey('agree'))).bottom,
          lessThanOrEqualTo(_screenBottom),
          reason: '$language hid its answers below the window',
        );

        await _drop(tester);
      }
    });

    testWidgets('the frame caps the card at the width the caller asked for', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpDialog(tester, language: language, maxWidth: 260);
        await _raise(tester);

        expect(
          tester.getRect(find.byKey(_dialogBranch(language))).width,
          260,
          reason: '$language ignored the width it was framed with',
        );

        await _drop(tester);
      }
    });

    testWidgets('the dark ramp keeps every card on its own shape', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpDialog(tester, language: language, brightness: Brightness.dark);
        await _raise(tester);

        expect(tester.takeException(), isNull, reason: '$language failed in dark');
        expect(find.byKey(_dialogBranch(language)), findsOneWidget, reason: '$language re-picked its card in dark');
        expect(_buttonRow, language == PureDesignLanguage.cupertino ? findsNothing : findsOneWidget);

        await _drop(tester);
      }
    });
  });

  group('toast', () {
    testWidgets('every design language draws its own plate', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpToast(tester, language: language);
        await _fire(tester);

        expect(tester.takeException(), isNull, reason: '$language failed to build a toast');
        expect(find.byKey(_toastBranch(language)), findsOneWidget, reason: '$language lost its plate');
        expect(find.text(_message), findsOneWidget, reason: '$language lost its message');

        await _expire(tester);
        expect(find.byKey(_toastBranch(language)), findsNothing, reason: '$language would not go away');
      }
    });

    testWidgets('the toast times out and takes itself away', (tester) async {
      await _pumpToast(tester, duration: const Duration(milliseconds: 400));
      await _fire(tester);
      expect(find.byKey(_toastBranch(PureDesignLanguage.material)), findsOneWidget);

      // The word is still up a moment before its life ends, and gone after it.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_toastBranch(PureDesignLanguage.material)), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(find.byKey(_toastBranch(PureDesignLanguage.material)), findsNothing);
      expect(find.text(_message), findsNothing);
    });

    testWidgets('a toast taken off the tree early leaves no timer behind', (tester) async {
      await _pumpToast(tester, duration: const Duration(seconds: 8));
      await _fire(tester);
      expect(find.byKey(_toastBranch(PureDesignLanguage.material)), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 9));
      expect(tester.takeException(), isNull);
      // An undisposed Timer or AnimationController fails the test at teardown.
    });

    testWidgets('the four kinds read as an alert or a status word', (tester) async {
      for (final type in PureToastType.values) {
        await _pumpToast(tester, type: type);
        await _fire(tester);

        final node = _semanticsAt(tester, _toastBranch(PureDesignLanguage.material)).properties;
        expect(node.label, _message, reason: '$type lost its word');
        expect(
          node.role,
          type == PureToastType.error || type == PureToastType.warning ? SemanticsRole.alert : SemanticsRole.status,
          reason: '$type read as the wrong kind of news',
        );

        await _expire(tester);
      }
      // The glyph the kind brings: a check for a success.
      await _pumpToast(tester, type: PureToastType.success);
      await _fire(tester);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      await _expire(tester);
    });

    testWidgets("a caller's glyph and colour travel with the plate", (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pumpToast(tester, language: language, icon: Icons.star, accent: Colors.teal);
        await _fire(tester);

        expect(find.byIcon(Icons.star), findsOneWidget, reason: '$language dropped the glyph it was handed');
        expect(tester.widget<Icon>(find.byIcon(Icons.star)).color, Colors.teal, reason: '$language dropped its colour');

        await _expire(tester);
        expect(find.byKey(_toastBranch(language)), findsNothing, reason: '$language would not go away');
      }
    });

    testWidgets('a toast with nowhere to be drawn is dropped, not thrown', (tester) async {
      // No Navigator, so no Overlay above this context: the message had nowhere
      // to be drawn and the call is a no-op rather than a crash.
      await tester.pumpWidget(
        PureConfigProvider(
          config: const UiConfig(language: PureDesignLanguage.fluent),
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => GestureDetector(
                key: const ValueKey('fire'),
                behavior: HitTestBehavior.opaque,
                onTap: () => PureToast.show(context, 'dropped'),
                child: const SizedBox(width: 60, height: 24),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('fire')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('dropped'), findsNothing);
    });

    testWidgets('a toast never answers a tap meant for the page', (tester) async {
      var taps = 0;
      await _pumpToast(tester, onUnder: () => taps++);
      await _fire(tester);

      // The plate does land over the control — the test is about the tap passing
      // through it, not about missing each other.
      final plate = tester.getRect(find.byKey(_toastBranch(PureDesignLanguage.material)));
      expect(plate.contains(tester.getCenter(find.byKey(const ValueKey('under')))), isTrue);

      await tester.tap(find.text('press me'));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.byKey(_toastBranch(PureDesignLanguage.material)), findsOneWidget);
      await _expire(tester);
    });
  });

  group('tooltip', () {
    testWidgets('every design language drops its own bubble on hover', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, _tip(), language: language);
        final pointer = await _hover(tester, tester.getCenter(find.byIcon(Icons.edit)));

        expect(tester.takeException(), isNull, reason: '$language failed to build a tooltip');
        expect(find.byKey(_tipBranch(language)), findsOneWidget, reason: '$language lost its bubble');
        expect(find.text(_hint), findsOneWidget, reason: '$language lost its word');

        await pointer.moveTo(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byKey(_tipBranch(language)), findsNothing, reason: '$language would not lift its bubble');
        await pointer.detach();
      }
    });

    testWidgets('the bubble waits for the wait the caller set', (tester) async {
      await _pump(tester, _tip(wait: const Duration(milliseconds: 600)));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: tester.getCenter(find.byIcon(Icons.edit)));
      addTearDown(pointer.removePointer);
      await tester.pump();

      // Resting on the trigger is not yet an answer.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_tipBranch(PureDesignLanguage.material)), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(_tipBranch(PureDesignLanguage.material)), findsOneWidget);
    });

    testWidgets('nothing is in the tree while the trigger rests', (tester) async {
      await _pump(tester, _tip());

      expect(find.byKey(_tipBranch(PureDesignLanguage.material)), findsNothing);
      expect(find.text(_hint), findsNothing);
      // The trigger itself is untouched: the wrapper adds no box of its own.
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('a long press pins the bubble until the next tap', (tester) async {
      await _pump(tester, _tip());

      await tester.longPress(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.byKey(_tipBranch(PureDesignLanguage.material)), findsOneWidget);

      // Pinned means it survives the finger leaving; a tap anywhere lifts it.
      await tester.tapAt(const Offset(300, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(_tipBranch(PureDesignLanguage.material)), findsNothing);
    });

    testWidgets('only macOS aims a point at its trigger', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, _tip(), language: language);
        final pointer = await _hover(tester, tester.getCenter(find.byIcon(Icons.edit)));

        final tail = find.descendant(of: find.byKey(_tipBranch(language)), matching: find.byType(CustomPaint));
        expect(
          tail,
          language == PureDesignLanguage.macos ? findsOneWidget : findsNothing,
          reason: "$language drew (or lost) the help tag's point",
        );

        await pointer.moveTo(const Offset(4, 4));
        await tester.pumpAndSettle();
        await pointer.detach();
      }
    });

    testWidgets('a trigger at the top of the screen gets its bubble below', (tester) async {
      await _pump(tester, _tip(), alignment: Alignment.topCenter);
      var pointer = await _hover(tester, tester.getCenter(find.byIcon(Icons.edit)));

      final trigger = tester.getRect(find.byIcon(Icons.edit));
      final bubble = tester.getRect(find.byKey(_tipBranch(PureDesignLanguage.material)));
      expect(bubble.top, greaterThan(trigger.top), reason: 'the bubble was pushed off the top edge');

      // And the same trigger near the bottom is answered above, as it is by
      // default.
      await pointer.moveTo(const Offset(4, 4));
      await tester.pumpAndSettle();
      await pointer.detach();
      await _pump(tester, _tip(), alignment: Alignment.bottomCenter);
      pointer = await _hover(tester, tester.getCenter(find.byIcon(Icons.edit)));
      final lowTrigger = tester.getRect(find.byIcon(Icons.edit));
      final highBubble = tester.getRect(find.byKey(_tipBranch(PureDesignLanguage.material)));
      expect(highBubble.bottom, lessThan(lowTrigger.bottom));
      await pointer.detach();
    });

    testWidgets('the trigger carries the word for a reader, and the bubble names itself', (tester) async {
      await _pump(tester, _tip());

      // At rest the help rides on the trigger, the way Flutter's own Tooltip
      // hands it over, without a bubble in the tree.
      expect(_semanticsAt(tester, const Key('PureTooltip.trigger')).properties.tooltip, _hint);

      final pointer = await _hover(tester, tester.getCenter(find.byIcon(Icons.edit)));
      expect(_semanticsAt(tester, _tipBranch(PureDesignLanguage.material)).properties.label, _hint);

      await pointer.moveTo(const Offset(4, 4));
      await tester.pumpAndSettle();
      await pointer.detach();
    });

    testWidgets('a tooltip on a live control leaves the control working', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        PureTooltip(
          message: _hint,
          child: TextButton(onPressed: () => taps++, child: const Text('rename')),
        ),
      );

      await tester.tap(find.text('rename'));
      await tester.pumpAndSettle();
      expect(taps, 1);

      final pointer = await _hover(tester, tester.getCenter(find.text('rename')));
      expect(find.byKey(_tipBranch(PureDesignLanguage.material)), findsOneWidget);

      await pointer.moveTo(const Offset(4, 4));
      await tester.pumpAndSettle();
    });

    testWidgets('every language still builds a tooltip with motion turned off', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, _tip(), language: language, animations: false);
        // The wait is the caller's own, motion off only stills the entrance.
        final pointer = await _hover(tester, tester.getCenter(find.byIcon(Icons.edit)));

        expect(tester.takeException(), isNull, reason: '$language failed without motion');
        expect(find.byKey(_tipBranch(language)), findsOneWidget, reason: '$language never showed its bubble');

        await pointer.moveTo(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byKey(_tipBranch(language)), findsNothing);
        await pointer.detach();
      }
    });
  });
}
