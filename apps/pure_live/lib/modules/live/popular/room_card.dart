import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/shared/shared.dart';

/// One recommended room as a card. The two designs — the grid tile and the
/// list row — are fixed; the saved appearance only decides which pieces of
/// information they draw.
///
/// The grid tile leads with the cover: the platform's mark and name in a pill
/// in its top-left corner, the room's category in the bottom-left chip and
/// the audience figure in the bottom-right one. The top-right corner holds
/// the red heart of a followed room — an unfollowed room says nothing there —
/// and the one state a feed cannot assume, a recording. A page that lists its
/// own rooms puts its ✕ there instead of the heart. Beneath the cover the
/// title keeps one line, then the anchor beside the avatar. The list row drops
/// the cover altogether: the streamer's avatar leads and the title, the
/// streamer and the audience fill three lines beside it.
///
/// Every piece is a Desen component over the theme's surface — the card, the
/// pills and the corner controls alike — so the corners follow the theme's
/// card radius rather than a radius of the card's own.
///
/// Every live room the app lists — the feeds, the follows, the history, the
/// search hits — is this card: a page adds what it knows and the card keeps
/// the design, rather than each page drawing its own tiles. The feeds wear
/// `RoomCardMenu` around it, which adds the hover label naming the room in
/// full and the right-click / long-press menu.
final class RoomCard extends ConsumerWidget {
  /// Shows [room]; [listRow] draws the list layout's row instead of the
  /// grid's cover-on-top card.
  ///
  /// [followable] false draws the followed heart inert and never touches the
  /// store — the preview's sample; [cover] replaces the room's own picture
  /// (the preview's bundled sample). [tags] and [cornerNote] carry a page's
  /// own line about the room, and [onRemove] swaps the heart for the page's
  /// way out of itself (the history's ✕).
  const RoomCard({
    required this.room,
    this.onOpen,
    this.listRow = false,
    this.followable = true,
    this.cover,
    this.tags = const [],
    this.cornerNote,
    this.onRemove,
    this.removeLabel,
    super.key,
  });

  /// The room shown.
  final LiveRoom room;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  /// Whether this is the feed's list layout, not its grid.
  final bool listRow;

  /// Whether the heart follows the room; false draws it inert.
  final bool followable;

  /// The picture over [RoomCard.room]'s own cover, when a caller brings one.
  final ImageProvider<Object>? cover;

  /// The follow tags the card draws under its meta line, joined by " · ".
  /// The list row has the line for them; the grid tile's height is fixed and
  /// leaves them to the list.
  final List<String> tags;

  /// A short line in the cover's bottom-right corner in place of the
  /// audience figure — the history's watch time, say.
  final String? cornerNote;

  /// Drops the room from the page that shows it, drawn as a ✕ in the
  /// cover's top-right corner in place of the follow heart.
  final VoidCallback? onRemove;

  /// The ✕'s accessible name; the common "delete" when the page has no
  /// wording of its own.
  final String? removeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final layout = ref.watch(browseSettingsProvider);
    final visibility = ref.watch(roomCardAppearanceProvider).visibility;
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final title = room.content.title;
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    final area = (room.area?.areaName ?? '').trim();
    final figure = audienceFigureOf(room, ref.watch(audienceMetricProvider), policy: ref.watch(audiencePolicyProvider));
    final radius = BorderRadius.circular(theme.radii.card);
    final platformIcon = localizedSiteIcon(site, size: 18);
    final platformName = site == null ? '' : localizedSiteShortName(site);
    final image = cover ?? cachedImage(room.content.coverUrl);
    // The preview's sample draws the followed heart without a store lookup:
    // that is the state worth showing, and the page must not follow anything.
    final followed =
        !followable ||
        ref.watch(
          followsProvider.select(
            (follows) => follows.rooms.any((entry) => entry.ref.identityKey == room.ref.identityKey),
          ),
        );
    final onFollow = followable
        ? () => unawaited(ref.read(followsProvider.notifier).remove(room.ref.identityKey))
        : null;
    // A feed already assumes a live room is on air, so the cover only names
    // the exception a viewer cannot see: a recording.
    final showsState = visibility.shows(RoomCardElement.status) && room.broadcast.isRecord;
    final pill = _StatePill(text: context.t.settings.roomCardReplay);
    // The page's ✕ takes the corner the heart holds: a card is either the
    // page's own list of rooms or a feed the viewer follows from. A page that
    // asks for it keeps the ✕ while its action is busy — inert, not a heart
    // the viewer never offered.
    final removeSemanticLabel = removeLabel ?? context.t.common.delete;
    final offersRemove = onRemove != null || removeLabel != null;
    final removeButton = offersRemove ? _RemoveButton(semanticLabel: removeSemanticLabel, onPressed: onRemove) : null;
    if (listRow) {
      return _ListRow(
        title: title,
        anchorName: anchorName,
        avatarUrl: avatarUrl,
        tags: tags,
        cornerNote: cornerNote,
        showsState: showsState,
        figure: visibility.shows(RoomCardElement.audience) ? figure : null,
        followed: followed,
        onFollow: onFollow,
        removeButton: removeButton,
        visibility: visibility,
        onOpen: onOpen,
      );
    }
    return DsCard(
      onPressed: onOpen,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
            final showsType = visibility.shows(RoomCardElement.coverType) && area.isNotEmpty;
            final showsAudience = visibility.shows(RoomCardElement.audience) && figure != null;
            final showsPlatform =
                visibility.shows(RoomCardElement.platformBadge) && (platformName.isNotEmpty || platformIcon != null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    DsImage(
                      image: image,
                      aspectRatio: layout.coverAspect.coverRatio,
                      semanticLabel: title,
                      fallback: CoverFallback(title: title),
                      style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card))),
                    ),
                    // Darkens the cover's lower edge so the chips keep their
                    // contrast over a bright picture.
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                      ),
                    ),
                    // The platform keeps the corner the state used to take:
                    // its mark and brand read at a glance, larger than the
                    // meta line ever had room for.
                    if (showsPlatform)
                      PositionedDirectional(
                        top: DsSpace.s8,
                        start: DsSpace.s8,
                        child: _PlatformMark(icon: platformIcon, name: platformName),
                      ),
                    PositionedDirectional(
                      top: DsSpace.s8,
                      end: DsSpace.s8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s6,
                        children: [
                          if (showsState) pill,
                          // The heart is the followed state, not an offer:
                          // an unfollowed room leaves the corner to the state.
                          if (removeButton != null) removeButton else if (followed) _FollowButton(onPressed: onFollow),
                        ],
                      ),
                    ),
                    if (showsType || showsAudience || cornerNote != null)
                      PositionedDirectional(
                        start: DsSpace.s8,
                        end: DsSpace.s8,
                        bottom: DsSpace.s8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // The category holds the corner it starts in and
                            // the figure the opposite one: the spacer takes
                            // whatever the category does not need, so the
                            // figure never drifts in off the right edge.
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: showsType
                                    ? RoomCoverChip(text: area, maxWidth: width * 0.55)
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            if (showsType && (showsAudience || cornerNote != null)) const SizedBox(width: DsSpace.s8),
                            if (cornerNote != null)
                              RoomCoverChip(text: cornerNote!, maxWidth: width * 0.45)
                            else if (showsAudience)
                              RoomCoverChip(
                                text: AudienceFormat.format(figure),
                                icon: DsIcons.flame,
                                maxWidth: width * 0.3,
                                style: DsTheme.of(context).typography.numeric(
                                  DsTheme.of(context).typography.caption
                                      .copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: _GridInfo(title: title, anchorName: anchorName, avatarUrl: avatarUrl, visibility: visibility),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The grid card's information area: the streamer's avatar on the left, the
/// title and the anchor aligned beside it — both starting at the same edge,
/// as the list row has them.
final class _GridInfo extends StatelessWidget {
  const _GridInfo({required this.title, required this.anchorName, required this.avatarUrl, required this.visibility});

  final String title;
  final String anchorName;
  final String avatarUrl;
  final RoomCardVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final showsTitle = visibility.shows(RoomCardElement.title) && title.isNotEmpty;
    final showsAnchor = visibility.shows(RoomCardElement.anchorName) && anchorName.isNotEmpty;
    return Padding(
      // The title sits close under the cover: the card reads as one block.
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          if (visibility.shows(RoomCardElement.avatar))
            DsAvatar(
              initials: anchorName.isEmpty ? title : anchorName,
              image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
              size: DsSize.md,
              semanticLabel: anchorName.isEmpty ? title : anchorName,
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                if (showsTitle)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodyStrong.copyWith(color: colors.text),
                  ),
                if (showsAnchor)
                  Text(
                    anchorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The list row's fixed design: the streamer's avatar on the left, then the
/// title, the streamer and — on a third line — the audience figure; the page's
/// ✕ or the followed heart closes the row. A list shows the rooms themselves,
/// so it draws no cover.
final class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.anchorName,
    required this.avatarUrl,
    required this.tags,
    required this.cornerNote,
    required this.showsState,
    required this.figure,
    required this.followed,
    required this.onFollow,
    required this.removeButton,
    required this.visibility,
    required this.onOpen,
  });

  final String title;
  final String anchorName;
  final String avatarUrl;
  final List<String> tags;
  final String? cornerNote;
  final bool showsState;
  final int? figure;
  final bool followed;
  final VoidCallback? onFollow;
  final Widget? removeButton;
  final RoomCardVisibility visibility;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final showsTitle = visibility.shows(RoomCardElement.title) && title.isNotEmpty;
    final showsAvatar = visibility.shows(RoomCardElement.avatar);
    final showsAnchor = visibility.shows(RoomCardElement.anchorName) && anchorName.isNotEmpty;
    final showsAudience = visibility.shows(RoomCardElement.audience) && figure != null;
    final showsNote = cornerNote != null;
    final hasMeta = showsAudience || showsNote || showsState;
    final caption = theme.typography.caption.copyWith(color: colors.textSubtle);
    final dot = Text('·', style: caption);
    return DsCard(
      onPressed: onOpen,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      // The tile's height comes from the feed (a list row is its own
      // measure, a tagged row a line taller); the row centres in it.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              if (showsAvatar)
                DsAvatar(
                  initials: anchorName.isEmpty ? title : anchorName,
                  image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                  size: DsSize.lg,
                  semanticLabel: anchorName.isEmpty ? title : anchorName,
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    if (showsTitle)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                      ),
                    if (showsAnchor)
                      Text(
                        anchorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    if (hasMeta)
                      Row(
                        spacing: DsSpace.s6,
                        children: [
                          if (showsAudience) DsIcon(DsIcons.flame, size: 12, color: colors.textSubtle),
                          if (showsAudience)
                            Text(AudienceFormat.format(figure), style: theme.typography.numeric(caption)),
                          if (showsAudience && showsNote) dot,
                          if (showsNote)
                            Flexible(
                              child: Text(cornerNote!, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                            ),
                          // A recording is the one state a list cannot assume;
                          // the pill names it where the cover used to.
                          if (showsState) _StatePill(text: context.t.settings.roomCardReplay, compact: true),
                        ],
                      ),
                    if (tags.isNotEmpty)
                      Text(tags.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                  ],
                ),
              ),
              if (removeButton != null) removeButton! else if (followed) _FollowButton(onPressed: onFollow),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's heart, drawn only while the room is followed: red on the
/// cover's dark glass, and the press lets the room go.
final class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _CornerButton(
    icon: DsIcons.heart,
    color: DsTheme.colorsOf(context).danger.fill,
    semanticLabel: context.t.favorites.unfollow,
    onPressed: onPressed,
  );
}

/// The page's way out of itself, in the heart's corner: the history's ✕.
final class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.semanticLabel, required this.onPressed});

  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      _CornerButton(icon: DsIcons.x, semanticLabel: semanticLabel, onPressed: onPressed);
}

/// One round control at a row's end or over a cover's top-right corner: a
/// Desen icon button, dark glass with the glyph at the caller's colour.
final class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = const Color(0xFFFFFFFF),
  });

  /// The circle's diameter.
  static const double dimension = 28;

  final DsIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DsButton.icon(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      size: DsSize.xs,
      variant: DsButtonVariant.ghost,
      icon: DsIcon(icon),
      style: DsButtonStyle(
        height: dimension,
        padding: EdgeInsets.zero,
        background: const Color(0x66000000),
        foreground: color,
        borderColor: const Color(0x26FFFFFF),
        borderWidth: 1,
        borderRadius: BorderRadius.circular(DsRadii.pill),
        iconSize: 14,
        shadows: const [],
        hovered: const DsButtonStyle(background: Color(0x8C000000)),
        pressed: const DsButtonStyle(background: Color(0xA6000000)),
      ),
    );
  }
}

/// The platform's mark and brand in a pill over the cover, at the size the
/// top-left corner can carry.
final class _PlatformMark extends StatelessWidget {
  const _PlatformMark({required this.icon, required this.name});

  final Widget? icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsBadge(
      label: Text(name),
      dot: false,
      icon: icon,
      style: DsBadgeStyle(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: name.isEmpty ? DsSpace.s6 : DsSpace.s8),
        background: const Color(0xB3000000),
        foreground: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        // The platform is the first thing the card names: a step above the
        // chips under it.
        textStyle: theme.typography.labelStrong,
        iconSize: 18,
        gap: DsSpace.s6,
      ),
    );
  }
}

/// The broadcast's exception in one pill over a cover: a recording, the only
/// state a feed cannot take for granted.
final class _StatePill extends StatelessWidget {
  const _StatePill({required this.text, this.compact = false});

  /// What the pill says: 回放.
  final String text;

  /// The smaller shape a list row's meta line uses.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsBadge(
      label: Text(text),
      dot: false,
      style: DsBadgeStyle(
        height: compact ? 18 : 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        background: const Color(0x8C000000),
        foreground: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(6),
        textStyle: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, fontSize: compact ? 10 : null),
      ),
    );
  }
}
