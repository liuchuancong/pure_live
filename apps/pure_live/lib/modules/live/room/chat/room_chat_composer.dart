part of 'room_chat.dart';

/// The chat composer: the field and the send button, only when the room's
/// chat accepts a posted message; a failure toasts, a success clears the
/// field.
final class _ChatComposer extends ConsumerStatefulWidget {
  const _ChatComposer();

  @override
  ConsumerState<_ChatComposer> createState() => _ChatComposerState();
}

final class _ChatComposerState extends ConsumerState<_ChatComposer> {
  final TextEditingController _field = TextEditingController();

  /// The emote panel: open until the viewer closes it — a picker that shut
  /// itself after every face would make a run of them impossible.
  bool _emotesOpen = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canSend = ref.watch(roomProvider.notifier).canSendDanmaku;
    if (!canSend) {
      // The platform's chat only listens: no composer stands here.
      return const SizedBox.shrink();
    }
    // The field owns the column's bottom: a hairline above it says where the
    // conversation ends and the viewer's own voice begins.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: DsTheme.colorsOf(context).border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            if (_emotesOpen) RoomEmotePanel(onPick: _insertEmote),
            Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: DsTextField(
                    controller: _field,
                    clearable: true,
                    placeholder: t.room.sendHint,
                    // The app's own ceiling for a posted message: the counter
                    // shows the room left, and the platforms' own limits still
                    // name themselves through the send's failure.
                    maxLength: 100,
                    onSubmitted: (word) => unawaited(_send(word)),
                    style: DsTextFieldStyle(borderRadius: BorderRadius.circular(DsRadii.pill)),
                  ),
                ),
                DsButton.icon(
                  variant: _emotesOpen ? DsButtonVariant.secondary : DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.room.emotes,
                  onPressed: () => setState(() => _emotesOpen = !_emotesOpen),
                  icon: const DsIcon(DsIcons.smile, size: 16),
                ),
                DsButton(onPressed: () => unawaited(_send(_field.text)), child: Text(t.room.send)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Puts an emote's code where the caret is — or at the line's end when the
  /// field has no say about a caret — and leaves the typing position there.
  void _insertEmote(String code) {
    final text = _field.text;
    final selection = _field.selection;
    final start = selection.start < 0 || selection.start > text.length ? text.length : selection.start;
    final end = selection.end < 0 || selection.end > text.length ? text.length : selection.end;
    _field.value = TextEditingValue(
      text: text.replaceRange(start, end, code),
      selection: TextSelection.collapsed(offset: start + code.length),
    );
  }

  Future<void> _send(String word) async {
    if (word.trim().isEmpty) return;
    final failure = await ref.read(roomProvider.notifier).sendDanmaku(word);
    if (!mounted) return;
    if (failure == null) {
      _field.clear();
    } else {
      // The platform's own reason: a refused send names what refused it.
      showDsToast(context: context, title: context.t.room.sendFailed, description: failure);
    }
  }
}

/// The emote panel: this room's own emoticons first (what the talk
/// has already used), then the bundled sheet's, every face drawn through the
/// same parser the lines use — one the chat cannot draw is one the panel does
/// not offer. A pick puts its code in the field and the panel stays up.
///
/// Public so the immersive room's composer bar and the landscape control
/// bar's input host the same panel the column's composer does. [onVideo]
/// draws it in the player's fixed dark plate instead of the theme's surface,
/// because a panel floating over the picture must not follow the app's
/// light/dark pick (the same rule [OnVideoColors] serves).
final class RoomEmotePanel extends ConsumerStatefulWidget {
  const RoomEmotePanel({required this.onPick, this.onVideo = false, super.key});

  final ValueChanged<String> onPick;

  /// Whether the panel floats over the picture and wears the on-video plate.
  final bool onVideo;

  @override
  ConsumerState<RoomEmotePanel> createState() => RoomEmotePanelState();
}

final class RoomEmotePanelState extends ConsumerState<RoomEmotePanel> {
  /// The bundled sheet's emoticon texts; read once, after the first build.
  List<String> _atlasCodes = const [];

  @override
  void initState() {
    super.initState();
    unawaited(
      emojiAtlasCodes().then((codes) {
        if (mounted) setState(() => _atlasCodes = codes);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final emotes = ref.watch(chatSeenEmotesProvider);
    final faces = [for (final emote in emotes) emote.code, ..._atlasCodes];
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final plate = widget.onVideo;
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      padding: const EdgeInsets.all(DsSpace.s8),
      decoration: BoxDecoration(
        color: plate ? OnVideoColors.menuPlate : colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        border: Border.all(color: plate ? OnVideoColors.inkHover : colors.border),
      ),
      child: faces.isEmpty
          ? Center(
              child: Text(
                t.room.emotesEmpty,
                style: theme.typography.caption.copyWith(color: plate ? OnVideoColors.inkMuted : colors.textMuted),
              ),
            )
          : SingleChildScrollView(
              child: Wrap(
                spacing: DsSpace.s4,
                runSpacing: DsSpace.s4,
                children: [
                  for (final code in faces)
                    _EmoteTile(code: code, emotes: emotes, onPick: widget.onPick, onVideo: plate),
                ],
              ),
            ),
    );
  }
}

/// One face the panel offers: the emoticon drawn at the line's own size, its
/// code the pick.
final class _EmoteTile extends StatelessWidget {
  const _EmoteTile({required this.code, required this.emotes, required this.onPick, this.onVideo = false});

  final String code;
  final List<LiveEmote> emotes;
  final ValueChanged<String> onPick;

  /// The on-video plate's own hover ink instead of the theme's.
  final bool onVideo;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: code,
      onPressed: () => onPick(code),
      builder: (context, states, _) => Container(
        height: 40,
        width: 48,
        alignment: Alignment.center,
        decoration: DsBoxDecoration(
          color:
              states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
              ? (onVideo ? OnVideoColors.inkHover : colors.hover)
              : null,
          borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
        ),
        child: RichText(
          maxLines: 1,
          text: TextSpan(children: chatWordSpans(code, theme.typography.caption, 22, emotes: emotes)),
        ),
      ),
    );
  }
}
