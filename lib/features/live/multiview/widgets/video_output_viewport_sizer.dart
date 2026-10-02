import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pure_live/player/utils/video_output_size_policy.dart';

typedef VideoOutputResizeCallback = Future<void> Function(int width, int height, bool force);

/// Keeps a native video output close to the visible physical viewport.
///
/// The caller retains ownership of the decoder and output controller. This
/// widget only observes layout/source dimensions and publishes debounced size
/// requests. [outputIdentity] fences late requests when a cell changes player.
class VideoOutputViewportSizer extends StatefulWidget {
  const VideoOutputViewportSizer({
    super.key,
    required this.outputIdentity,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.fit,
    required this.onResize,
    required this.child,
    this.resizeDebounce = const Duration(milliseconds: 180),
  }) : assert(resizeDebounce >= Duration.zero);

  final Object outputIdentity;
  final Stream<int?> sourceWidth;
  final Stream<int?> sourceHeight;
  final BoxFit fit;
  final VideoOutputResizeCallback onResize;
  final Widget child;
  final Duration resizeDebounce;

  @override
  State<VideoOutputViewportSizer> createState() => _VideoOutputViewportSizerState();
}

class _VideoOutputViewportSizerState extends State<VideoOutputViewportSizer> {
  StreamSubscription<int?>? _widthSubscription;
  StreamSubscription<int?>? _heightSubscription;
  Timer? _resizeTimer;
  int? _sourceWidth;
  int? _sourceHeight;
  Size? _logicalViewport;
  double _devicePixelRatio = 1;
  Size? _requestedSize;
  bool _hasPublishedViewport = false;

  @override
  void initState() {
    super.initState();
    _bindSourceDimensions();
  }

  @override
  void didUpdateWidget(covariant VideoOutputViewportSizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sourceWidth, widget.sourceWidth) ||
        !identical(oldWidget.sourceHeight, widget.sourceHeight)) {
      unawaited(_cancelSourceSubscriptions());
      _sourceWidth = null;
      _sourceHeight = null;
      _bindSourceDimensions();
      _scheduleResize();
    }
    if (!identical(oldWidget.outputIdentity, widget.outputIdentity)) {
      _requestedSize = null;
      _hasPublishedViewport = false;
      _scheduleResize();
    }
    if (oldWidget.fit != widget.fit) {
      _scheduleResize();
    }
  }

  void _bindSourceDimensions() {
    _widthSubscription = widget.sourceWidth.distinct().listen((value) {
      _sourceWidth = value;
      _scheduleResize();
    });
    _heightSubscription = widget.sourceHeight.distinct().listen((value) {
      _sourceHeight = value;
      _scheduleResize();
    });
  }

  Future<void> _cancelSourceSubscriptions() async {
    // Capture before awaiting. didUpdateWidget binds the replacement streams
    // immediately; a late field read could cancel those new subscriptions.
    final widthSubscription = _widthSubscription;
    final heightSubscription = _heightSubscription;
    _widthSubscription = null;
    _heightSubscription = null;
    await Future.wait<void>([
      if (widthSubscription != null) widthSubscription.cancel(),
      if (heightSubscription != null) heightSubscription.cancel(),
    ]);
  }

  void _scheduleResize() {
    final viewport = _logicalViewport;
    if (viewport == null) return;
    final target = calculateVideoOutputSize(
      logicalViewport: viewport,
      devicePixelRatio: _devicePixelRatio,
      sourceWidth: _sourceWidth,
      sourceHeight: _sourceHeight,
      fit: widget.fit,
    );
    if (target.isEmpty || target == _requestedSize) return;

    _resizeTimer?.cancel();
    _resizeTimer = Timer(widget.resizeDebounce, () async {
      if (!mounted) return;
      final identity = widget.outputIdentity;
      final resize = widget.onResize;
      final force = !_hasPublishedViewport;
      try {
        await resize(target.width.toInt(), target.height.toInt(), force);
        if (!mounted || !identical(widget.outputIdentity, identity)) return;
        _requestedSize = target;
        _hasPublishedViewport = true;
      } catch (_) {
        if (identical(widget.outputIdentity, identity)) {
          _requestedSize = null;
          _hasPublishedViewport = false;
        }
        // The output may be disposed while a route, cell or window transition
        // completes. A later mounted layout will publish a fresh target.
      }
    });
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    unawaited(_cancelSourceSubscriptions());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        if (_logicalViewport != viewport || _devicePixelRatio != pixelRatio) {
          _logicalViewport = viewport;
          _devicePixelRatio = pixelRatio;
          _scheduleResize();
        }
        return widget.child;
      },
    );
  }
}
