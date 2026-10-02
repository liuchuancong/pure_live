import 'package:flutter/widgets.dart';

/// Owns a control-bar hover lease, including when the bar is replaced/unmounted.
/// MouseRegion does not emit onExit for a disappearing widget.
class ControlHoverRegion extends StatefulWidget {
  const ControlHoverRegion({
    super.key,
    required this.enabled,
    required this.onEnter,
    required this.onExit,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<Object> onEnter;
  final ValueChanged<Object> onExit;
  final Widget child;

  @override
  State<ControlHoverRegion> createState() => _ControlHoverRegionState();
}

class _ControlHoverRegionState extends State<ControlHoverRegion> {
  final _owner = Object();
  final _devices = <int>{};
  ValueChanged<Object>? _release;
  int _revision = 0;

  void _acquire() {
    if (!mounted || !widget.enabled || _devices.isEmpty || _release != null) return;
    _release = widget.onExit;
    widget.onEnter(_owner);
  }

  void _relinquish() {
    final release = _release;
    _release = null;
    release?.call(_owner);
  }

  @override
  void didUpdateWidget(ControlHoverRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled &&
        oldWidget.onEnter == widget.onEnter &&
        oldWidget.onExit == widget.onExit) {
      return;
    }
    _relinquish();
    final revision = ++_revision;
    // Acquiring can reveal Rx controls. Do not notify them during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == _revision) _acquire();
    });
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (event) {
      _devices.add(event.device);
      _acquire();
    },
    onExit: (event) {
      _devices.remove(event.device);
      if (_devices.isEmpty) _relinquish();
    },
    child: widget.child,
  );

  @override
  void dispose() {
    _revision++;
    _devices.clear();
    _relinquish();
    super.dispose();
  }
}
