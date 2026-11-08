import 'dart:async' show Timer;

import 'package:flutter/widgets.dart';

/// The rest a card's cover preview waits for: the pointer arrives, half a
/// second passes without leaving, and the preview mounts over the cover; the
/// pointer leaving — or a press, which means the content is about to open on
/// top of it — takes it back at once. A keyboard's focus walks are never a
/// rest, so they play nothing, and a grid walked fast never opens a stream
/// under every card the pointer crossed.
mixin CoverPreviewDwell<T extends StatefulWidget> on State<T> {
  /// The rest between the pointer's arrival and the preview's first frame.
  static const Duration dwell = Duration(milliseconds: 500);

  /// Whether this card previews at all — the page's own choice.
  bool get coverPreviewEnabled;

  /// Whether this card's content may preview (a live broadcast can; a replay
  /// or an offline channel cannot).
  bool get coverPreviewAllowed => true;

  /// The preview itself, drawn over the cover while [coverPreviewing].
  Widget buildCoverPreview();

  Timer? _dwell;
  bool _previewing = false;

  /// Whether the preview is on the cover now.
  bool get coverPreviewing => _previewing;

  /// Feeds the card's pressable states in; call from the states controller's
  /// listener.
  void syncCoverPreview(Set<WidgetState> states) {
    if (!coverPreviewEnabled) return;
    if (states.contains(WidgetState.pressed)) return _end();
    if (!states.contains(WidgetState.hovered) || !coverPreviewAllowed) return _end();
    _dwell ??= Timer(dwell, () {
      _dwell = null;
      if (mounted && !_previewing) setState(() => _previewing = true);
    });
  }

  /// Takes the preview back; safe to call whether one is showing or not.
  void endCoverPreview() => _end();

  void _end() {
    _dwell?.cancel();
    _dwell = null;
    if (_previewing && mounted) setState(() => _previewing = false);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    super.dispose();
  }
}
