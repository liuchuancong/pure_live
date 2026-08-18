part of '../floating.dart';

/// Widget switching utility.
///
/// Depending on current PiP status will render [childWhenEnabled]
/// or [childWhenDisabled] widget.
class PiPSwitcher extends StatefulWidget {
  /// Floating instance that the listener will connect to.
  @visibleForTesting
  final Floating? floating;

  /// Child to render when PiP is enabled
  final Widget childWhenEnabled;

  /// Child to render when PiP is disabled or unavailable.
  final Widget childWhenDisabled;

  /// Switch animation's duration.
  final Duration duration;

  /// Switch animation's curve.
  final Curve curve;

  const PiPSwitcher({
    super.key,
    required this.childWhenEnabled,
    required this.childWhenDisabled,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
    this.floating,
  });

  @override
  State<PiPSwitcher> createState() => _PipAwareState();
}

class _PipAwareState extends State<PiPSwitcher> {
  late final _floating = widget.floating ?? Floating();

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: _floating.pipStatusStream,
        initialData: PiPStatus.disabled,
        builder: (context, snapshot) => AnimatedSwitcher(
          duration: widget.duration,
          switchInCurve: widget.curve,
          switchOutCurve: widget.curve,
          child: snapshot.data == PiPStatus.enabled
              ? widget.childWhenEnabled
              : widget.childWhenDisabled,
        ),
      );
}
