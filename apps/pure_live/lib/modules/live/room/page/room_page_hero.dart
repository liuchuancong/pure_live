part of 'room_page.dart';

/// The word shown on entering the portrait full screen: the one gesture there
/// cannot be seen. Swiping up or down over the picture's middle third moves to
/// the next or previous room in the list this one came from, and nothing else
/// on the surface says so — the ✕ and the switcher button both show
/// themselves.
///
/// It borrows the reference's shape (a pill above the bottom rows, gone after
/// three seconds) and keeps its honesty: it is drawn only where the swipe is
/// actually live, so it can never teach a gesture the settings turned off.
final class _PortraitSwipeHint extends StatefulWidget {
  const _PortraitSwipeHint();

  @override
  State<_PortraitSwipeHint> createState() => _PortraitSwipeHintState();
}

final class _PortraitSwipeHintState extends State<_PortraitSwipeHint> {
  static const Duration _visibleFor = Duration(seconds: 3);

  bool _visible = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _hide = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The fade is the whole animation; with reduce-motion on, the pill is
    // simply gone when its seconds are up.
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: Center(
        child: PlayerGlassPill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
            child: Text(
              context.t.room.portraitSwipeHint,
              textAlign: TextAlign.center,
              style: DsTheme.of(context).typography.caption.copyWith(color: OnVideoColors.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// A running clock for the compact facts row, without a ticking widget: the
/// row rebuilds on the room's own updates, and a snapshot is enough for a
/// number that is not the thing being watched.
String _roomClock(DateTime since) {
  final elapsed = DateTime.now().difference(since);
  String two(int value) => value.toString().padLeft(2, '0');
  if (elapsed.isNegative) return '00:00:00';
  return '${two(elapsed.inHours)}:${two(elapsed.inMinutes.remainder(60))}:${two(elapsed.inSeconds.remainder(60))}';
}
