import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_player.dart';

void main() {
  testWidgets('temporarily hiding video preserves the mounted texture subtree', (tester) async {
    var mounted = 0;
    var disposed = 0;

    Widget build(bool visible) {
      return MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: StableVideoLayer(
            visible: visible,
            video: _MountProbe(onMount: () => mounted++, onDispose: () => disposed++),
            placeholder: const ColoredBox(color: Colors.black),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(true));
    expect(mounted, 1);

    await tester.pumpWidget(build(false));
    await tester.pumpWidget(build(true));

    expect(mounted, 1);
    expect(disposed, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, 1);
  });
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.onMount, required this.onDispose});

  final VoidCallback onMount;
  final VoidCallback onDispose;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.blue);
}
