// The caption strip: what it draws, what a press reaches, and how a window call
// that fails is surfaced. This coverage lived in the app while the strip did too;
// the presentations now sit behind `PureTitleBar`, so the assertions moved with
// them and drive the seam through a recorder rather than a live window.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const List<Key> _captionKeys = [
  ValueKey<String>('title-minimize'),
  ValueKey<String>('title-maximize'),
  ValueKey<String>('title-close'),
];

void main() {
  for (final language in PureDesignLanguage.values) {
    testWidgets('the strip draws the three caption controls under ${language.name}', (tester) async {
      await _pump(tester, language, _Recorder());

      for (final key in _captionKeys) {
        expect(find.byKey(key), findsOneWidget, reason: '${language.name} is missing $key');
      }
    });

    testWidgets('minimise and close reach the seam untouched under ${language.name}', (tester) async {
      final actions = _Recorder();
      await _pump(tester, language, actions);

      await tester.tap(find.byKey(const ValueKey('title-minimize')));
      await tester.tap(find.byKey(const ValueKey('title-close')));
      await tester.pump();

      // `isMaximized` is the strip's own poll (no listenable was handed in), not
      // something a button asked for.
      expect(actions.calls.where((call) => call != 'isMaximized'), ['minimize', 'close']);
    });
  }

  testWidgets('the maximise control follows the listenable and toggles once', (tester) async {
    final maximized = ValueNotifier<bool>(false);
    addTearDown(maximized.dispose);
    final actions = _Recorder();
    await _pump(tester, PureDesignLanguage.material, actions, maximized: maximized);

    expect(find.byTooltip('Maximize'), findsOneWidget);
    maximized.value = true;
    await tester.pump();
    expect(find.byTooltip('Restore'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('title-maximize')));
    await tester.pump();
    expect(actions.calls, ['toggleMaximize']);
  });

  testWidgets('an overlapping maximise is not started twice', (tester) async {
    final maximized = ValueNotifier<bool>(false);
    addTearDown(maximized.dispose);
    final gate = Completer<void>();
    final actions = _Recorder(hangMaximizeOn: gate.future);
    await _pump(tester, PureDesignLanguage.material, actions, maximized: maximized);

    await tester.tap(find.byKey(const ValueKey('title-maximize')));
    await tester.tap(find.byKey(const ValueKey('title-maximize')));
    await tester.pump();

    expect(actions.calls, ['toggleMaximize'], reason: 'the second press landed while the first was in flight');
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failing window call is reported, not thrown at the button', (tester) async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    await _pump(tester, PureDesignLanguage.material, _Recorder(failWith: StateError('plugin is gone')));
    await tester.tap(find.byKey(const ValueKey('title-close')));
    await tester.pump();

    expect(reported, hasLength(1));
    expect('${reported.single.context}', contains('Failed to close the window.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip polls the window when the caller brings no listenable', (tester) async {
    final actions = _Recorder(maximized: true);
    await _pump(tester, PureDesignLanguage.material, actions);

    expect(actions.calls, contains('isMaximized'));
    expect(find.byTooltip('Restore'), findsOneWidget);
  });

  testWidgets('a drag on the title region reaches the seam', (tester) async {
    final actions = _Recorder();
    await _pump(tester, PureDesignLanguage.material, actions);

    final drag = await tester.startGesture(tester.getCenter(find.byType(PureTitleBarDragRegion)));
    await drag.moveBy(const Offset(40, 4));
    await drag.up();
    await tester.pump();

    expect(actions.calls, contains('startDragging'));

    // The pointer ends up resting over a caption button, whose hover timer
    // outlives the tree unless it is run out here.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the caller can dress the strip in another language', (tester) async {
    // Material trails its close control after the title, on the right; macOS
    // leads the strip with it, on the left. The theme says Material either way,
    // so the move proves the argument — not the theme — was consulted.
    final actions = _Recorder();
    await _pump(tester, PureDesignLanguage.material, actions);
    final material = tester.getTopLeft(find.byKey(const ValueKey('title-close'))).dx;

    await _pump(tester, PureDesignLanguage.material, actions, designLanguage: PureDesignLanguage.macos);
    final macOS = tester.getTopLeft(find.byKey(const ValueKey('title-close'))).dx;

    expect(macOS, lessThan(material));
  });
}

Future<void> _pump(
  WidgetTester tester,
  PureDesignLanguage language,
  WindowChromeActions actions, {
  ValueListenable<bool>? maximized,
  PureDesignLanguage? designLanguage,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Center(
          child: PureTitleBar(
            designLanguage: designLanguage,
            labels: const PureTitleBarLabels(title: 'Pure Live'),
            actions: actions,
            maximized: maximized,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The seam the strip drives, recording what it was asked for.
final class _Recorder implements WindowChromeActions {
  new({this.maximized = false, this.failWith, this.hangMaximizeOn});

  final List<String> calls = [];
  final bool maximized;
  final Error? failWith;
  final Future<void>? hangMaximizeOn;

  @override
  Future<void> minimize() => _record('minimize');

  @override
  Future<void> close() => _record('close');

  @override
  Future<void> startDragging() => _record('startDragging');

  @override
  Future<bool> isMaximized() async {
    calls.add('isMaximized');
    return maximized;
  }

  @override
  Future<void> toggleMaximize() async {
    calls.add('toggleMaximize');
    if (failWith case final failure?) throw failure;
    await hangMaximizeOn;
  }

  Future<void> _record(String name) async {
    calls.add(name);
    if (failWith case final failure?) throw failure;
  }
}
