part of 'room_chat.dart';

/// Whether [message] is the same speaker's next plain line after [above] — the
/// run a chat column stops re-labelling. Anything paid, a notice or a membership
/// card is not a `chat` line, so the run's own type test already breaks on them
/// — and so does another sender, because the line that follows has to say what
/// it is again.
bool _continuesSpeaker(LiveMessage above, LiveMessage message) {
  if (message.type != LiveMessageType.chat || above.type != LiveMessageType.chat) return false;
  final name = message.sender?.userName.trim() ?? '';
  if (name.isEmpty || name != above.sender?.userName.trim()) return false;
  final at = message.createdAt;
  final aboveAt = above.createdAt;
  if (at != null && aboveAt != null && at.difference(aboveAt) > const Duration(minutes: 2)) return false;
  return true;
}

/// One chat line: the sender and the text, the platform's own colour when
/// it gave one. Its context menu copies the line, blocks the sender, or
/// blocks a keyword to cut out of the line.
final class _ChatLine extends ConsumerWidget {
  const _ChatLine({required this.message, this.anchorName = '', this.platform = '', this.repeats = false});

  final LiveMessage message;

  /// The platform the room lives on, for the user card the name opens.
  final String platform;

  /// The room's streamer: a gift names its receiver only when it differs.
  final String anchorName;

  /// Whether the line above is the same speaker's own talk. A run of messages
  /// from one person says who it is once: the second line keeps the column's
  /// indent and drops the face, the badges and the name.
  final bool repeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sender = message.sender;
    var nameStyle = theme.typography.caption;
    final senderName = sender?.userName.trim() ?? '';
    const showNames = true;
    const fontSize = kChatListFontSizeFixed;
    const lineSpacing = kChatListLineSpacingFixed;
    final height = switch (lineSpacing) {
      'compact' => 1.4,
      'loose' => 1.7,
      _ => 1.5,
    };
    final vertical = switch (lineSpacing) {
      // The tightest step on the spacing scale: a compact list still needs
      // lines that read apart.
      'compact' => 1.0,
      'loose' => DsSpace.s8,
      _ => DsSpace.s6,
    };
    final fontPx = fontSize > 0 ? fontSize.toDouble() : 15.0;
    final lineStyle = theme.typography.caption.copyWith(fontSize: fontPx, height: height, color: colors.text);
    // The sender leads the line: a touch heavier than the words, so the eye
    // lands on who is talking before it reads what was said. The ink is the
    // name's own, never the words': most platforms send white, and white
    // names vanish on a pale panel.
    //
    // Who speaks is said before what is said: the streamer and the staff wear
    // the room's own two inks — the same accent and green the role chips carry —
    // so a moderator's line reads apart in a column of hundreds without the
    // chip being needed. Everyone else keeps the colour the platform sent.
    final roleInk = switch (sender?.role) {
      LiveAnchorRole.anchor => colors.accent,
      LiveAnchorRole.moderator => colors.success.text,
      LiveAnchorRole.platform => colors.info.text,
      _ => null,
    };
    nameStyle = theme.typography.caption.copyWith(
      fontSize: fontPx,
      height: height,
      fontWeight: FontWeight.w600,
      color:
          roleInk ??
          chatSenderNameInk(
            sender: sender,
            messageColor: message.color,
            background: colors.surface,
            fallback: colors.textMuted,
          ),
    );
    // The line's own pixel size, followed from the viewer's setting; an
    // emoticon rides a touch larger than its words.
    final gift = _giftOf(message);
    final superChat = message.type == LiveMessageType.superChat && message.payload is LiveSuperChatMessage
        ? message.payload! as LiveSuperChatMessage
        : null;
    final replayed = message.messageId.startsWith('local-replay-');
    final words = gift == null ? message.text : giftSentenceText(t, gift, anchorName);
    // The room's own notices (the platform's notice and system lines) sit
    // apart from the conversation: centred, quiet, no "系统:" voice. A chat
    // message whose platform lost the sender's name is NOT a notice — it
    // stays in the flow, left-aligned, as written.
    final isSystem =
        gift == null &&
        superChat == null &&
        (message.type == LiveMessageType.notice || message.type == LiveMessageType.system);
    // Who is talking, in the room's own terms: the badge pictures the platform
    // sent, the role it declares, the fan medal (its name and level) and the
    // viewer's level. A line with none of them shows none.
    final fanBadgeLevel = (sender?.fanBadgeLevel ?? '').trim();
    final userLevelNumber = int.tryParse((sender?.userLevel ?? '').trim()) ?? 0;
    final fanLevelNumber = int.tryParse(fanBadgeLevel) ?? 0;
    // One rank per row: the platform's user level when it has one, else
    // the room's fan level. Two badges for one person read as a duplicate.
    final levelNumber = userLevelNumber > 0 ? userLevelNumber : fanLevelNumber;
    final roleTag = switch (sender?.role) {
      LiveAnchorRole.anchor => t.room.roleAnchor,
      LiveAnchorRole.moderator => t.room.roleModerator,
      LiveAnchorRole.platform => t.room.rolePlatform,
      _ => null,
    };
    // One height for every tag on the line, tied to the viewer's own chat size:
    // tags of three different heights are what made the column look broken.
    final tagHeight = (fontPx * 1.55).clamp(20.0, 28.0);
    final badgeStyle = theme.typography.caption.copyWith(fontSize: math.max(fontPx - 2, 10), height: 1);
    if (isSystem) {
      // A notice is not conversation: it sits in a quiet chip of its own, so
      // the flow of talk reads as talk and the room's own voice reads apart.
      final line = Padding(
        padding: EdgeInsets.symmetric(vertical: vertical),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: 1),
            decoration: BoxDecoration(
              color: colors.control.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(DsRadii.pill),
            ),
            child: Text(
              words,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                fontSize: fontSize > 0 ? math.max(fontSize - 1, 10).toDouble() : null,
                height: height,
                color: colors.textSubtle,
              ),
            ),
          ),
        ),
      );
      return DsContextMenuRegion(
        semanticLabel: t.room.messageActions,
        items: [
          DsMenuItem(
            leading: const DsIcon(DsIcons.copy),
            label: Text(t.room.copy),
            onPressed: () => unawaited(copyRoomMessageText(context, words)),
          ),
        ],
        child: _ChatHover(child: line),
      );
    }
    // Every line is the same row: a 2 px rail, then the identity and the
    // words. Paid lines colour the rail and lead with their gift/price mark;
    // ordinary talk keeps the rail transparent. No avatar, no bordered card,
    // so the column reads as one stream instead of two layouts.
    final paid = gift != null || superChat != null;
    final priceText = superChat == null ? null : _superChatPrice(superChat);
    final showName = showNames && senderName.isNotEmpty && !repeats;
    final spans = <InlineSpan>[
      if (priceText != null)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
            child: _SenderTag(
              text: priceText,
              background: colors.warning.fill,
              foreground: colors.warning.onFill,
              style: badgeStyle.copyWith(fontWeight: FontWeight.w600),
              height: tagHeight,
            ),
          ),
        ),
      if (showName) ...[
        if (roleTag != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
              child: _SenderTag(
                text: roleTag,
                background: switch (sender?.role) {
                  LiveAnchorRole.anchor => colors.accent.withValues(alpha: 0.16),
                  LiveAnchorRole.moderator => colors.success.tint,
                  _ => colors.info.tint,
                },
                foreground: switch (sender?.role) {
                  LiveAnchorRole.anchor => colors.accent,
                  LiveAnchorRole.moderator => colors.success.text,
                  _ => colors.info.text,
                },
                style: badgeStyle,
                height: tagHeight,
              ),
            ),
          ),
        if (levelNumber > 0)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s3),
              child: UserLevelBadge(level: levelNumber, height: tagHeight),
            ),
          ),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _ChatName(
            name: senderName,
            style: nameStyle,
            onPressed: sender == null || platform.isEmpty
                ? null
                : () => unawaited(showChatUserCard(context, ref, sender, platform)),
          ),
        ),
        TextSpan(
          text: ': ',
          style: nameStyle.copyWith(color: colors.textSubtle, fontWeight: FontWeight.w400),
        ),
      ],
      if (replayed)
        TextSpan(
          text: '[${t.room.replayed}] ',
          style: nameStyle.copyWith(color: colors.textSubtle),
        ),
      ...chatWordSpans(words, lineStyle, fontPx * 1.2, emotes: message.emotes.toList(growable: false)),
    ];
    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        repeats ? DsSpace.s12 : DsSpace.s6,
        paid ? DsSpace.s4 : vertical,
        2,
        paid ? DsSpace.s4 : vertical,
      ),
      child: Text.rich(TextSpan(style: lineStyle, children: spans)),
    );
    // A tap on the words opens the same copy/block sheet as a right click;
    // the name keeps its own tap for the user card.
    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          unawaited(showRoomMessageActions(context, ref, text: words, userName: senderName, isLocal: message.isLocal)),
      child: content,
    );
    return DsContextMenuRegion(
      semanticLabel: t.room.messageActions,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.copy),
          label: Text(t.room.copy),
          // Who said it is half of what a quoted line says, so the name rides
          // along for every kind of line, and what is copied is what the column
          // showed — not the platform's raw text with its emoticon codes in it.
          onPressed: () => unawaited(copyRoomMessageText(context, senderName.isEmpty ? words : '$senderName: $words')),
        ),
        // A masked name (`观***`, what a guest sees of a Bilibili viewer) is not
        // an identity: the shield's list reads it as every viewer whose name
        // starts the same way, so this row would offer to hide a crowd.
        if (!message.isLocal && senderName.isNotEmpty && !DanmakuBlockList.isMaskedName(senderName))
          DsMenuItem(
            leading: const DsIcon(DsIcons.ban),
            label: Text(t.room.blockUser),
            onPressed: () => unawaited(blockRoomMessageSender(context, ref, senderName)),
          ),
        if (!message.isLocal)
          DsMenuItem(
            leading: const DsIcon(DsIcons.shield),
            label: Text(t.room.blockKeyword),
            onPressed: () => unawaited(blockRoomMessageKeyword(context, ref, message.text)),
          ),
      ],
      child: _ChatHover(child: row),
    );
  }
}

/// The sender's name inside a chat line: a text, not a chip, that opens the
/// user card when pressed. It keeps the line's own type and ink.
final class _ChatName extends StatelessWidget {
  const _ChatName({required this.name, required this.style, this.onPressed});

  final String name;
  final TextStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
    if (onPressed == null) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: text),
    );
  }
}

/// The hover ink under a chat line.
///
/// Every line carries actions — a right click on the desktop, a long press on
/// touch — and a bare line of text never says so (§20.2: a control's reach is
/// shown by hover or focus, not by luck). The fill is the theme's own hover
/// colour at half strength, so the row reads like every other row in the app
/// and never fights a paid line's banner underneath it.
final class _ChatHover extends StatefulWidget {
  const _ChatHover({required this.child});

  final Widget child;

  @override
  State<_ChatHover> createState() => _ChatHoverState();
}

final class _ChatHoverState extends State<_ChatHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered ? colors.accent.withValues(alpha: 0.10) : OnVideoColors.clear,
          borderRadius: theme.radii.controlCorners(null, 24),
        ),
        child: widget.child,
      ),
    );
  }
}

/// The filled-in name inks, keyed by the platform colour and the ground it
/// was measured against: the same few colours come back all night, so the
/// walk over lightness runs once per pair rather than once per line.
final Map<(int, int), Color> _nameInks = {};

/// The ink a sender's name is written in on [background]: the platform's own
/// name colour (17LIVE), else the colour a coloured danmaku carries. White
/// and black are no colour at all — those lines take [fallback] — and any
/// other is walked towards black or white until it clears 4.5:1, so a name
/// never sinks into the panel it sits on. The reference's `chatNameInk`.
///
/// Public so the immersive room's chat overlay, whose pills stand on the
/// picture's own dark glass instead of the panel's surface, reads the same
/// names the column does.
Color chatSenderNameInk({
  required MessageSender? sender,
  required LiveMessageColor? messageColor,
  required Color background,
  required Color fallback,
}) {
  final source = sender?.nameColor ?? messageColor;
  final named = source == null ? null : (r: source.r, g: source.g, b: source.b);
  if (named == null ||
      (named.r == 255 && named.g == 255 && named.b == 255) ||
      (named.r == 0 && named.g == 0 && named.b == 0)) {
    // The platform gave nothing readable: the name takes a hue of its own,
    // hashed from the name so one speaker keeps one colour — the reference's
    // column reads many hues, not a wall of grey.
    final ground = background.withValues(alpha: 1);
    final dark = ground.computeLuminance() < 0.35;
    final seed = (sender?.userName.trim().isEmpty ?? true) ? 0 : sender!.userName.trim().codeUnitAt(0);
    final hue = (seed * 47) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.58, dark ? 0.70 : 0.42).toColor();
  }
  final color = Color.fromARGB(255, named.r, named.g, named.b);
  final ground = background.withValues(alpha: 1);
  final key = (color.toARGB32(), ground.toARGB32());
  if (_nameInks[key] case final known?) return known;
  if (_nameInks.length >= 512) _nameInks.clear();
  return _nameInks[key] = _readableNameInk(color, ground);
}

/// [color] kept as it is when it clears 4.5:1 on [background], else moved
/// one percent at a time towards black or white — whichever that surface
/// stands further from, where one of them always lands.
Color _readableNameInk(Color color, Color background) {
  double contrast(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
  }

  if (contrast(color, background) >= 4.5) return color;
  final darker = InkOnColor.darkInkOn(background);
  final hsl = HSLColor.fromColor(color);
  var lightness = hsl.lightness;
  while (true) {
    lightness = (lightness + (darker ? -0.01 : 0.01)).clamp(0.0, 1.0);
    final next = hsl.withLightness(lightness).toColor();
    if (contrast(next, background) >= 4.5 || lightness == 0 || lightness == 1) return next;
  }
}

/// The [LiveGift] a platform gift line carries; null for anything else (a
/// local gift carries a map and keeps its plain text).
LiveGift? _giftOf(LiveMessage message) =>
    message.type == LiveMessageType.gift && message.payload is LiveGift ? message.payload! as LiveGift : null;

/// The price as the platform writes it for others to see ("￥12"); null when
/// the card has none of its own.
String? _superChatPrice(LiveSuperChatMessage message) {
  final shown = message.price.displayText.trim();
  if (shown.isNotEmpty) return shown;
  final amount = message.price.amount;
  if (amount == null || amount <= 0) return null;
  return [?message.price.currency, '$amount'].join();
}

/// A small inline chip on a chat line: a fan badge (its name and level) or
/// the viewer's level, in the platform's own labels.
/// One sender tag beside the name: the platform's fan medal, the room role, the
/// price of a paid line.
///
/// A rectangle, not a pill — the platforms draw their medals as plates, and a
/// row of pills on every line reads as a row of buttons. The height is locked
/// to the line's own size so a tag never pushes the next line down, and the
/// digits ride the numeric face so `Lv.9` and `Lv.24` take the same width.
final class _SenderTag extends StatelessWidget {
  const _SenderTag({
    required this.text,
    required this.background,
    required this.foreground,
    required this.style,
    required this.height,
  });

  final String text;
  final Color background;
  final Color foreground;
  final TextStyle style;

  /// The tag's own height; the corners follow it, the way a control's do.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
      decoration: BoxDecoration(color: background, borderRadius: theme.radii.controlCorners(null, height)),
      child: Text(text, style: style.apply(color: foreground), maxLines: 1),
    );
  }
}
