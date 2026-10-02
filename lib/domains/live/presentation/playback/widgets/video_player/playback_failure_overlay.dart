import 'package:flutter/material.dart';
import 'package:pure_live/core/utils/i18n.dart';

/// Terminal failure stays actionable without replacing the native video subtree.
class PlaybackFailureOverlay extends StatefulWidget {
  const PlaybackFailureOverlay({super.key, required this.hasError, required this.onRetry, required this.child});

  final bool hasError;
  final Future<void> Function() onRetry;
  final Widget child;

  @override
  State<PlaybackFailureOverlay> createState() => _PlaybackFailureOverlayState();
}

class _PlaybackFailureOverlayState extends State<PlaybackFailureOverlay> {
  bool _retrying = false;
  bool _retryFailed = false;

  @override
  void didUpdateWidget(PlaybackFailureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasError && !widget.hasError) _retryFailed = false;
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    try {
      await widget.onRetry();
    } catch (_) {
      // The room refresh normally owns its error UI; retain an action if it throws.
      if (mounted) setState(() => _retryFailed = true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.hasError || _retryFailed || _retrying) ...[
          const IgnorePointer(child: ColoredBox(color: Color(0x55000000))),
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 360, maxHeight: constraints.maxHeight * 0.65),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Material(
                    color: const Color(0xEE202124),
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              i18nOr('playback_failure_title', 'Playback interrupted'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i18nOr('playback_failure_hint', 'Reload the room to get a fresh stream.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _retrying ? null : _retry,
                            icon: const Icon(Icons.refresh),
                            label: Text(i18nOr('retry', 'Retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
