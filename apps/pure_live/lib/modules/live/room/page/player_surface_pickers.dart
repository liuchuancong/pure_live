part of 'player_surface.dart';

// State members hosted by an extension: the receiver is the State, so
// its protected setState is safe to call here.
// ignore_for_file: invalid_use_of_protected_member

final class _StreamPickerRow extends ConsumerWidget {
  const _StreamPickerRow({
    required this.room,
    required this.open,
    required this.anchors,
    required this.labelled,
    required this.fitOnly,
    required this.onToggle,
  });

  final RoomState room;

  /// The catalogue currently open, if any.
  final _Picker? open;

  /// Each picker's box: the card opens over the button that raised it.
  final Map<_Picker, GlobalKey> anchors;

  /// Whether the current choice's words fit beside the glyph.
  final bool labelled;

  /// A narrow strip keeps only the picture's fit; quality and line are in More.
  final bool fitOnly;

  final ValueChanged<_Picker> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final lines = room.lines;
    final lineIndex = room.lineIndex.clamp(0, lines.isEmpty ? 0 : lines.length - 1);
    final line = lines.isEmpty ? null : lines[lineIndex];
    final quality = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
    final fit = ref.watch(playbackSettingsProvider).fit;
    final tv = PlayerBarTier.tvOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: tv ? DsSpace.s8 : DsSpace.s4,
      children: [
        if (!fitOnly && room.qualities.isNotEmpty && quality != null)
          _button(
            context,
            picker: _Picker.quality,
            icon: DsIcons.gauge,
            label: quality.displayLabel,
            semanticLabel: t.room.quality,
          ),
        if (!fitOnly && line != null)
          _button(
            context,
            picker: _Picker.line,
            icon: DsIcons.route,
            label: _lineShortLabel(t, line, lineIndex),
            semanticLabel: t.room.lineLabel,
          ),
        _button(
          context,
          picker: _Picker.fit,
          icon: DsIcons.aspectRatio,
          label: fitLabels(t)[fit.index],
          semanticLabel: t.settings.fit,
        ),
      ],
    );
  }

  /// One picker: the glyph, the current choice's words when there is room, and
  /// the chevron that points the way the card opens — up, over the bar.
  Widget _button(
    BuildContext context, {
    required _Picker picker,
    required DsIconData icon,
    required String label,
    required String semanticLabel,
  }) {
    final theme = DsTheme.of(context);
    final tv = PlayerBarTier.tvOf(context);
    final isOpen = open == picker;
    final side = tv ? theme.sizes.lg : theme.sizes.sm;
    return KeyedSubtree(
      key: anchors[picker],
      child: MouseRegion(
        // The whole current value rides the tooltip: the words beside the
        // glyph truncate, and the glyph-only pass carries none of it.
        child: DsTooltip(
          message: label,
          child: DsPressable(
            semanticLabel: semanticLabel,
            onPressed: () => onToggle(picker),
            builder: (context, states, _) {
              final focused = states.contains(WidgetState.focused);
              final lit = isOpen || states.contains(WidgetState.hovered) || focused;
              final corners = theme.radii.controlCorners(null, side);
              return Container(
                height: side,
                padding: EdgeInsets.symmetric(
                  horizontal: tv
                      ? DsSpace.s12
                      : labelled
                      ? DsSpace.s8
                      : DsSpace.s6,
                ),
                decoration: DsBoxDecoration(color: lit ? _onVideoHover : null, borderRadius: corners),
                foregroundDecoration: tv && focused
                    ? BoxDecoration(
                        border: Border.all(color: OnVideoColors.foreground, width: 2),
                        borderRadius: corners,
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s4,
                  children: [
                    // With room for words the glyph steps aside: 「原画
                    // 1080P60 ⌄」 reads as the reference draws it.
                    if (!labelled)
                      DsIcon(icon, size: tv ? theme.sizes.iconLg : theme.sizes.iconSm, color: _onVideoMuted),
                    if (labelled)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: tv ? 128 : 96),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // A TV reads from across the room: the value takes
                          // the control-label size instead of the caption.
                          style: (tv ? theme.typography.label : theme.typography.caption).copyWith(color: _onVideo),
                        ),
                      ),
                    DsIcon(isOpen ? DsIcons.chevronDown : DsIcons.chevronUp, size: tv ? 14 : 12, color: _onVideoMuted),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A catalogue a narrow page's More menu can ask the picture surface to open.
enum RoomStreamPicker { quality, line, fit }

/// The ask raised by the room's More menu when quality or line moves there on
/// a narrow strip.
final roomStreamPickerAskProvider = NotifierProvider<_RoomStreamPickerAskController, int>(
  _RoomStreamPickerAskController.new,
);

final class _RoomStreamPickerAskController extends Notifier<int> {
  RoomStreamPicker? _last;

  @override
  int build() => 0;

  RoomStreamPicker? get last => _last;

  void ask(RoomStreamPicker picker) {
    _last = picker;
    state++;
  }
}

/// The catalogues the control bar offers: the stream's quality and the line
/// behind it. The picture's fit is the page's menu row, not a catalogue.
enum _Picker { quality, line, fit }

/// The line's words on the strip: the platform's own label when it reads as
/// one, the position otherwise. Bilibili labels a line
/// `host|protocol|format|codec`, which never belongs on a button.
String _lineShortLabel(Translations t, LivePlayLine line, int index) {
  final own = (line.lineLabel ?? '').trim();
  if (own.isEmpty || own.contains('|') || own.length > 14) return t.room.line(n: index + 1);
  return own;
}

/// What a line is, under its name in the panel: the container and the codec,
/// the two facts a viewer compares lines by.
String? _lineDetail(LivePlayLine line) {
  final format = switch (line.format) {
    LiveStreamFormat.mpegts => 'MPEG-TS',
    LiveStreamFormat.webrtc => 'WebRTC',
    _ => line.format.name.toUpperCase(),
  };
  final codec = switch (line.codec) {
    LiveStreamCodec.avc => 'H.264',
    LiveStreamCodec.hevc => 'H.265',
    LiveStreamCodec.av1 => 'AV1',
    LiveStreamCodec.vp9 => 'VP9',
    LiveStreamCodec.unknown || null => '',
  };
  return codec.isEmpty ? format : '$format · $codec';
}

extension _PlayerSurfaceStreamPickers on _PlayerSurfaceState {
  /// The picker machinery behind the control bar's stream chips: which

  void _showPicker(_Picker picker) {
    if (_openPicker == picker) return;
    final wasClosed = _openPicker == null;
    setState(() => _openPicker = picker);
    if (wasClosed) _setPanelOpen(true);
  }

  /// The visible button a catalogue opens from: quality and line have no
  /// button of their own on a narrow strip, so their card opens over fit.
  GlobalKey _pickerAnchor(_Picker picker) {
    final own = _pickerAnchors[picker]!;
    if (own.currentContext != null) return own;
    return _pickerAnchors[_Picker.fit]!;
  }

  void _hidePicker() {
    if (_openPicker == null) return;
    setState(() => _openPicker = null);
    _setPanelOpen(false);
  }

  void _togglePicker(_Picker picker) {
    _wake();
    if (_openPicker == picker) {
      _hidePicker();
    } else {
      _showPicker(picker);
    }
  }

  /// The open picker's catalogue.
  Widget _pickerPanel(Translations t, _Picker picker) {
    final room = widget.roomState;
    final controller = ref.read(roomProvider.notifier);
    switch (picker) {
      case _Picker.quality:
        final current = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
        return PlayerOverlayPanel(
          title: t.room.quality,
          width: _panelWidth(picker),
          children: [
            for (final option in room.qualities)
              PlayerPanelOption(
                label: option.displayLabel,
                selected: option == current,
                onPressed: () {
                  _hidePicker();
                  unawaited(controller.selectQuality(option));
                },
              ),
          ],
        );
      case _Picker.line:
        return PlayerOverlayPanel(
          title: t.room.lineLabel,
          width: _panelWidth(picker),
          children: [
            for (final (index, option) in room.lines.indexed)
              PlayerPanelOption(
                label: _lineShortLabel(t, option, index),
                detail: _lineDetail(option),
                selected: index == room.lineIndex,
                onPressed: () {
                  _hidePicker();
                  unawaited(controller.selectLine(index));
                },
              ),
          ],
        );
      case _Picker.fit:
        final current = ref.read(playbackSettingsProvider).fit;
        final labels = fitLabels(t);
        return PlayerOverlayPanel(
          title: t.settings.fit,
          width: _panelWidth(picker),
          children: [
            for (final option in PlaybackFit.values)
              PlayerPanelOption(
                label: labels[option.index],
                selected: option == current,
                onPressed: () {
                  _hidePicker();
                  unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option));
                },
              ),
          ],
        );
    }
  }
}

/// The width each catalogue asks for; the host centres the card on its
/// picker with this measure.
double _panelWidth(_Picker picker) => switch (picker) {
  _Picker.quality => 200,
  _Picker.line => 240,
  _Picker.fit => 180,
};
