import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/widgets/video_output_viewport_sizer.dart';

typedef _ResizeCall = ({int width, int height, bool force});

Widget _host({
  required Size size,
  required double devicePixelRatio,
  required Object outputIdentity,
  required Stream<int?> sourceWidth,
  required Stream<int?> sourceHeight,
  required List<_ResizeCall> calls,
  BoxFit fit = BoxFit.contain,
  Duration debounce = const Duration(milliseconds: 20),
}) {
  return MediaQuery(
    data: MediaQueryData(devicePixelRatio: devicePixelRatio),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: VideoOutputViewportSizer(
            outputIdentity: outputIdentity,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            fit: fit,
            resizeDebounce: debounce,
            onResize: (width, height, force) async {
              calls.add((width: width, height: height, force: force));
            },
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('publishes the visible physical viewport after one debounce', (tester) async {
    final width = StreamController<int?>.broadcast();
    final height = StreamController<int?>.broadcast();
    addTearDown(width.close);
    addTearDown(height.close);
    final calls = <_ResizeCall>[];

    await tester.pumpWidget(
      _host(
        size: const Size(400, 300),
        devicePixelRatio: 2,
        outputIdentity: Object(),
        sourceWidth: width.stream,
        sourceHeight: height.stream,
        calls: calls,
      ),
    );
    await tester.pump(const Duration(milliseconds: 19));
    expect(calls, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, [(width: 800, height: 450, force: true)]);
  });

  testWidgets('coalesces window changes and follows published source geometry', (tester) async {
    final width = StreamController<int?>.broadcast();
    final height = StreamController<int?>.broadcast();
    addTearDown(width.close);
    addTearDown(height.close);
    final identity = Object();
    final calls = <_ResizeCall>[];

    Future<void> pumpAt(Size size) => tester.pumpWidget(
      _host(
        size: size,
        devicePixelRatio: 2,
        outputIdentity: identity,
        sourceWidth: width.stream,
        sourceHeight: height.stream,
        calls: calls,
      ),
    );

    await pumpAt(const Size(400, 300));
    await tester.pump(const Duration(milliseconds: 20));
    calls.clear();

    await pumpAt(const Size(300, 200));
    await tester.pump(const Duration(milliseconds: 10));
    await pumpAt(const Size(200, 100));
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, [(width: 356, height: 200, force: false)]);

    width.add(640);
    height.add(480);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls.last, (width: 268, height: 200, force: false));
  });

  testWidgets('new output identity forces reattachment even at the same size', (tester) async {
    final width = StreamController<int?>.broadcast();
    final height = StreamController<int?>.broadcast();
    addTearDown(width.close);
    addTearDown(height.close);
    final calls = <_ResizeCall>[];

    Future<void> pumpFor(Object identity) => tester.pumpWidget(
      _host(
        size: const Size(320, 180),
        devicePixelRatio: 1,
        outputIdentity: identity,
        sourceWidth: width.stream,
        sourceHeight: height.stream,
        calls: calls,
      ),
    );

    await pumpFor(Object());
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls.single.force, isTrue);

    await pumpFor(Object());
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, hasLength(2));
    expect(calls.last, (width: 320, height: 180, force: true));
  });

  testWidgets('fit changes resize the native output for the fitted viewport', (tester) async {
    final width = StreamController<int?>.broadcast();
    final height = StreamController<int?>.broadcast();
    addTearDown(width.close);
    addTearDown(height.close);
    final identity = Object();
    final calls = <_ResizeCall>[];

    Future<void> pumpFor(BoxFit fit) => tester.pumpWidget(
      _host(
        size: const Size(500, 500),
        devicePixelRatio: 1,
        outputIdentity: identity,
        sourceWidth: width.stream,
        sourceHeight: height.stream,
        calls: calls,
        fit: fit,
      ),
    );

    await pumpFor(BoxFit.contain);
    width.add(1920);
    height.add(1080);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls.single, (width: 500, height: 282, force: true));

    await pumpFor(BoxFit.cover);
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls.last, (width: 890, height: 500, force: false));
  });

  testWidgets('keyed focus promotion swaps big and small render targets', (tester) async {
    final width = StreamController<int?>.broadcast();
    final height = StreamController<int?>.broadcast();
    addTearDown(width.close);
    addTearDown(height.close);
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final identityA = Object();
    final identityB = Object();
    final callsA = <_ResizeCall>[];
    final callsB = <_ResizeCall>[];

    Widget surface({required GlobalKey key, required Object identity, required List<_ResizeCall> calls}) {
      return VideoOutputViewportSizer(
        key: key,
        outputIdentity: identity,
        sourceWidth: width.stream,
        sourceHeight: height.stream,
        fit: BoxFit.contain,
        resizeDebounce: const Duration(milliseconds: 20),
        onResize: (outputWidth, outputHeight, force) async {
          calls.add((width: outputWidth, height: outputHeight, force: force));
        },
        child: const SizedBox.expand(),
      );
    }

    Widget focusHost({required bool focusA}) {
      return MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 180,
              child: Row(
                children: focusA
                    ? [
                        Expanded(
                          flex: 3,
                          child: surface(key: keyA, identity: identityA, calls: callsA),
                        ),
                        Expanded(
                          child: surface(key: keyB, identity: identityB, calls: callsB),
                        ),
                      ]
                    : [
                        Expanded(
                          flex: 3,
                          child: surface(key: keyB, identity: identityB, calls: callsB),
                        ),
                        Expanded(
                          child: surface(key: keyA, identity: identityA, calls: callsA),
                        ),
                      ],
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(focusHost(focusA: true));
    await tester.pump(const Duration(milliseconds: 20));
    expect(callsA.single, (width: 300, height: 170, force: true));
    expect(callsB.single, (width: 100, height: 56, force: true));
    callsA.clear();
    callsB.clear();

    await tester.pumpWidget(focusHost(focusA: false));
    await tester.pump(const Duration(milliseconds: 20));
    expect(callsA.single, (width: 100, height: 56, force: false));
    expect(callsB.single, (width: 300, height: 170, force: false));
  });

  testWidgets('unmounted surface cancels a pending resize', (tester) async {
    final width = StreamController<int?>.broadcast();
    final height = StreamController<int?>.broadcast();
    addTearDown(width.close);
    addTearDown(height.close);
    final calls = <_ResizeCall>[];

    await tester.pumpWidget(
      _host(
        size: const Size(400, 300),
        devicePixelRatio: 1,
        outputIdentity: Object(),
        sourceWidth: width.stream,
        sourceHeight: height.stream,
        calls: calls,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 30));

    expect(calls, isEmpty);
  });
}
