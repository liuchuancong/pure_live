// Module: lib/src/lyrics_surface.dart
// Purpose: The shell's lyric surface over flutter_lyric: parse any supported
// format and drive the view from a playback position.
// Author: liuchuancong
// Created: 2026-10-10
//
// flutter_lyric covers LRC, YRC (word-timed) and QRC plus translation lines;
// this widget only bridges PureLive's inputs (lyric text + progress) onto its
// controller. Parsing, scrolling, highlighting and selection all stay in the
// market package.

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_parse.dart';
import 'package:flutter_lyric/widgets/lyric_view.dart';

/// The lyric surface for one song's text.
final class LyricsSurface extends StatefulWidget {
  const LyricsSurface({required this.lyricText, required this.progress, this.translationText, super.key});

  /// Raw lyric document in any flutter_lyric supported format (LRC/YRC/QRC).
  final String lyricText;

  /// Optional translation document, line-aligned with the main lyric.
  final String? translationText;

  /// The playback position; drives highlighting and auto-scroll.
  final Duration progress;

  @override
  State<LyricsSurface> createState() => _LyricsSurfaceState();
}

final class _LyricsSurfaceState extends State<LyricsSurface> {
  late final LyricController _controller = LyricController();

  @override
  void initState() {
    super.initState();
    _loadLyric();
  }

  @override
  void didUpdateWidget(covariant LyricsSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyricText != oldWidget.lyricText || widget.translationText != oldWidget.translationText) {
      _loadLyric();
    }
    if (widget.progress != oldWidget.progress) {
      _controller.progressNotifier.value = widget.progress;
    }
  }

  void _loadLyric() {
    _controller.lyricNotifier.value = LyricParse.parse(widget.lyricText, translationLyric: widget.translationText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LyricView(controller: _controller);
  }
}
