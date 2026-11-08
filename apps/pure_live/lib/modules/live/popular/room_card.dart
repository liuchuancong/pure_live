import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
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
/// The cover keeps its quiet pieces resident — the platform, the audience,
/// the recording — and lets the pieces a viewer acts on or reads once arrive
/// with attention: the heart (or the page's ✕) and the category chip fade in
/// on hover or keyboard focus and fade out with the pointer. A touch screen
/// has no hover, so there they stay on screen; [hoverReveal] false opts out
/// entirely (the settings preview shows every piece at once).
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
  /// way out of itself (the history's ✕). [hoverReveal] false keeps every
  /// cover piece on screen without waiting for a pointer. [livePreview] true
  /// plays the room's own stream on the cover while a pointer rests on the
  /// card, and takes it back when the pointer leaves.
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
    this.hoverReveal = true,
    this.livePreview = false,
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

  /// Whether the grid cover's heart and category chip wait for hover or
  /// focus; false keeps them resident (the settings preview).
  final bool hoverReveal;

  /// Whether resting a pointer on the card plays the room's own stream on
  /// the cover. The list row has no cover and takes no preview.
  final bool livePreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Everything the card draws that is a fact about the app — the saved
    // visibility, the figure's reading, the followed state, the platform's
    // mark — resolves here, and the view below takes plain values. The view
    // renders without a store (tests, samples, a surface without Riverpod),
    // and these watches stay the only rebuild paths.
    final visibility = ref.watch(roomCardSettingsProvider).visibility;
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final figure = audienceFigureOf(room, ref.watch(audienceMetricProvider), policy: ref.watch(audiencePolicyProvider));
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
    return RoomCardView(
      room: room,
      onOpen: onOpen,
      listRow: listRow,
      cover: cover,
      tags: tags,
      cornerNote: cornerNote,
      onRemove: onRemove,
      removeLabel: removeLabel,
      hoverReveal: hoverReveal,
      livePreview: livePreview,
      visibility: visibility,
      figure: figure,
      followed: followed,
      onFollow: onFollow,
      platformIcon: localizedSiteIcon(site, size: DsTheme.sizesOf(context).iconSm),
      platformName: site == null ? '' : localizedSiteShortName(site),
    );
  }
}

/// The room card's rendering over plain values: no store, no provider — the
/// resolver in [RoomCard] hands the saved visibility, the audience figure,
/// the followed state and the platform's mark in, and this draws them. The
/// two designs — the grid tile and the list row — are fixed here; the
/// visibility decides which pieces of information they draw.
final class RoomCardView extends StatelessWidget {
  /// Draws [room] with the resolved values; the parameters mean what
  /// [RoomCard]'s do.
  const RoomCardView({
    required this.room,
    required this.visibility,
    required this.figure,
    required this.followed,
    required this.platformIcon,
    required this.platformName,
    this.onFollow,
    this.onOpen,
    this.listRow = false,
    this.cover,
    this.tags = const [],
    this.cornerNote,
    this.onRemove,
    this.removeLabel,
    this.hoverReveal = true,
    this.livePreview = false,
    super.key,
  });

  /// The room shown.
  final LiveRoom room;

  /// The saved appearance: which pieces of information the card draws.
  final RoomCardVisibility visibility;

  /// The audience figure as the viewer's metric choice reads it.
  final int? figure;

  /// Whether the room is followed; the grid tile draws the heart for it.
  final bool followed;

  /// The follow toggle; null leaves the heart inert (or absent).
  final VoidCallback? onFollow;

  /// The platform's mark and name, as the site registry reads them.
  final Widget? platformIcon;
  final String platformName;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  /// Whether this is the feed's list layout, not its grid.
  final bool listRow;

  /// The picture over [room]'s own cover, when a caller brings one.
  final ImageProvider<Object>? cover;

  /// The follow tags the card draws under its meta line, joined by " · ".
  final List<String> tags;

  /// A short line in the cover's bottom-right corner in place of the
  /// audience figure.
  final String? cornerNote;

  /// Drops the room from the page that shows it, drawn as a ✕.
  final VoidCallback? onRemove;

  /// The ✕'s accessible name; the common "delete" when the page has no
  /// wording of its own.
  final String? removeLabel;

  /// Whether the grid cover's heart and category chip wait for hover or
  /// focus; false keeps them resident.
  final bool hoverReveal;

  /// Whether resting a pointer on the card plays the room's own stream on
  /// the cover. The list row has no cover and takes no preview.
  final bool livePreview;

  @override
  Widget build(BuildContext context) {
    final title = room.content.title;
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    final area = (room.area?.areaName ?? '').trim();
    final image = cover ?? cachedImage(room.content.coverUrl, policy: ImageCachePolicies.liveRoomCover);
    // A feed already assumes a live room is on air, so the cover only names
    // the exception a viewer cannot see: a recording.
    final showsState = visibility.shows(RoomCardElement.status) && room.broadcast.isRecord;
    // The page's ✕ takes the corner the heart holds: a card is either the
    // page's own list of rooms or a feed the viewer follows from. A page that
    // asks for it keeps the ✕ while its action is busy — inert, not a heart
    // the viewer never offered.
    final removeSemanticLabel = removeLabel ?? context.t.common.delete;
    final offersRemove = onRemove != null || removeLabel != null;
    final removeButton = offersRemove
        ? _RemoveButton(semanticLabel: removeSemanticLabel, onPressed: onRemove, onCover: !listRow)
        : null;
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
    return _GridTile(
      room: room,
      image: image,
      title: title,
      anchorName: anchorName,
      avatarUrl: avatarUrl,
      area: area,
      visibility: visibility,
      figure: figure,
      followed: followed,
      onFollow: onFollow,
      platformIcon: platformIcon,
      platformName: platformName,
      showsState: showsState,
      removeButton: removeButton,
      cornerNote: cornerNote,
      onOpen: onOpen,
      hoverReveal: hoverReveal,
      livePreview: livePreview,
    );
  }
}

/// The grid tile: the cover with its corner pieces, then the information
/// area. It owns the card's interaction states so the cover can reveal its
/// interactive pieces — the heart (or the page's ✕) and the category chip —
/// on hover or keyboard focus without adding a focus stop of its own: the
/// states ride the card's own pressable through [DsCard.statesController].
final class _GridTile extends StatefulWidget {
  const _GridTile({
    required this.room,
    required this.image,
    required this.title,
    required this.anchorName,
    required this.avatarUrl,
    required this.area,
    required this.visibility,
    required this.figure,
    required this.followed,
    required this.onFollow,
    required this.platformIcon,
    required this.platformName,
    required this.showsState,
    required this.removeButton,
    required this.cornerNote,
    required this.onOpen,
    required this.hoverReveal,
    required this.livePreview,
  });

  final LiveRoom room;
  final ImageProvider<Object> image;
  final String title;
  final String anchorName;
  final String avatarUrl;
  final String area;
  final RoomCardVisibility visibility;
  final int? figure;
  final bool followed;
  final VoidCallback? onFollow;
  final Widget? platformIcon;
  final String platformName;
  final bool showsState;
  final Widget? removeButton;
  final String? cornerNote;
  final VoidCallback? onOpen;
  final bool hoverReveal;
  final bool livePreview;

  @override
  State<_GridTile> createState() => _GridTileState();
}

final class _GridTileState extends State<_GridTile> {
  /// The card's own interaction states, observed through the pressable:
  /// hover and focus reveal the cover's pieces, a press rebuilds nothing.
  final WidgetStatesController _states = WidgetStatesController();
  bool _hoverOrFocus = false;

  /// The rest between the pointer's arrival and the live preview's first
  /// frame: a grid walk must not open a stream under every card it crosses.
  static const Duration _previewDwell = Duration(milliseconds: 500);

  Timer? _dwell;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  void _onStates() {
    final value = _states.value;
    final next = value.contains(WidgetState.hovered) || value.contains(WidgetState.focused);
    if (next != _hoverOrFocus) setState(() => _hoverOrFocus = next);
    _syncPreview(value);
  }

  /// The live preview follows the pointer alone: a rest on the card starts
  /// it, the pointer leaving takes it back, and a press ends it at once —
  /// the room is about to open on top of it. A keyboard's focus walks are
  /// never a rest, so they play nothing.
  void _syncPreview(Set<WidgetState> value) {
    if (!widget.livePreview) return;
    if (value.contains(WidgetState.pressed)) return _endPreview();
    if (!value.contains(WidgetState.hovered) || !widget.room.broadcast.isLiveNow) return _endPreview();
    _dwell ??= Timer(_previewDwell, () {
      _dwell = null;
      if (mounted && _states.value.contains(WidgetState.hovered) && !_previewing) {
        setState(() => _previewing = true);
      }
    });
  }

  void _endPreview() {
    _dwell?.cancel();
    _dwell = null;
    if (_previewing && mounted) setState(() => _previewing = false);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _states.removeListener(_onStates);
    _states.dispose();
    super.dispose();
  }

  /// Whether the cover's interactive pieces are on screen: a mouse reveals
  /// them on hover and a keyboard on focus; a finger or a remote has neither,
  /// so touch platforms keep them resident. The preview opts out entirely.
  bool get _revealed {
    if (!widget.hoverReveal || _hoverOrFocus) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  /// Fades a piece with the theme's tone motion and takes it out of reach
  /// and the semantics tree while it is away — the layout never shifts.
  Widget _reveal(Widget child) {
    final motion = DsTheme.of(context).motion;
    return AnimatedOpacity(
      opacity: _revealed ? 1 : 0,
      duration: motion.toneDuration,
      curve: motion.toneCurve,
      child: IgnorePointer(
        ignoring: !_revealed,
        child: ExcludeSemantics(excluding: !_revealed, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final radius = BorderRadius.circular(theme.radii.card);
    final visibility = widget.visibility;
    final showsType = visibility.shows(RoomCardElement.coverType) && widget.area.isNotEmpty;
    final showsAudience = visibility.shows(RoomCardElement.audience) && widget.figure != null;
    final showsPlatform =
        visibility.shows(RoomCardElement.platformBadge) &&
        (widget.platformName.isNotEmpty || widget.platformIcon != null);
    final pill = _StatePill(text: context.t.settings.roomCardReplay);
    return DsCard(
      onPressed: widget.onOpen,
      statesController: _states,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    DsImage(
                      image: widget.image,
                      aspectRatio: kRoomCardCoverRatio,
                      semanticLabel: widget.title,
                      fallback: CoverFallback(title: widget.title),
                      style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card))),
                    ),
                    // Darkens the cover's lower edge so the chips keep their
                    // contrast over a bright picture.
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                      ),
                    ),
                    // The hover's live preview: the room's own picture, played
                    // where the cover stood in for it. It sits under the
                    // corner pieces, so the card's facts keep reading over the
                    // moving picture.
                    if (widget.livePreview && _previewing) Positioned.fill(child: RoomLivePreview(room: widget.room)),
                    // The platform keeps the corner the state used to take:
                    // its mark and brand read at a glance, larger than the
                    // meta line ever had room for.
                    if (showsPlatform)
                      PositionedDirectional(
                        top: DsSpace.s8,
                        start: DsSpace.s8,
                        child: _PlatformMark(icon: widget.platformIcon, name: widget.platformName),
                      ),
                    PositionedDirectional(
                      top: DsSpace.s8,
                      end: DsSpace.s8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s6,
                        children: [
                          // The heart is the followed state, not an offer:
                          // an unfollowed room says nothing here. It arrives
                          // with attention; the state pill holds the corner
                          // so the resident piece never moves.
                          if (widget.removeButton != null)
                            _reveal(widget.removeButton!)
                          else if (widget.followed)
                            _reveal(_FollowButton(onPressed: widget.onFollow)),
                          if (widget.showsState) pill,
                        ],
                      ),
                    ),
                    if (showsType || showsAudience || widget.cornerNote != null)
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
                                    ? _reveal(RoomCoverChip(text: widget.area, maxWidth: width * 0.55))
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            if (showsType && (showsAudience || widget.cornerNote != null))
                              const SizedBox(width: DsSpace.s8),
                            if (widget.cornerNote != null)
                              RoomCoverChip(text: widget.cornerNote!, maxWidth: width * 0.45)
                            else if (showsAudience)
                              RoomCoverChip(
                                text: AudienceFormat.format(widget.figure),
                                icon: DsIcons.flame,
                                maxWidth: width * 0.3,
                                style: theme.typography.numeric(
                                  theme.typography.caption.copyWith(
                                    color: OnVideoColors.foreground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: _GridInfo(
                    title: widget.title,
                    anchorName: widget.anchorName,
                    avatarUrl: widget.avatarUrl,
                    visibility: visibility,
                  ),
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
      // The vertical pair stays within the feed's fixed information extent.
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s8),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          if (visibility.shows(RoomCardElement.avatar))
            DsAvatar(
              initials: avatarInitials(anchorName.isEmpty ? title : anchorName),
              image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl, policy: ImageCachePolicies.avatar),
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
                  initials: avatarInitials(anchorName.isEmpty ? title : anchorName),
                  image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl, policy: ImageCachePolicies.avatar),
                  size: DsSize.lg,
                  semanticLabel: anchorName.isEmpty ? title : anchorName,
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
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
                            Flexible(
                              child: Text(
                                AudienceFormat.format(figure),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.numeric(caption),
                              ),
                            ),
                          if (showsAudience && showsNote) dot,
                          if (showsNote)
                            Flexible(
                              child: Text(cornerNote!, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                            ),
                          // A recording is the one state a list cannot assume;
                          // the pill names it where the cover used to.
                          if (showsState) _StatePill(text: context.t.settings.roomCardReplay),
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

/// The card's heart, drawn only while the room is followed: a red glyph over
/// the cover, and the press lets the room go.
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
  const _RemoveButton({required this.semanticLabel, required this.onPressed, required this.onCover});

  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Whether the ✕ sits over a cover (white, as on a picture) or at a row's
  /// end on the card's own surface (the theme's muted ink).
  final bool onCover;

  @override
  Widget build(BuildContext context) => _CornerButton(
    icon: DsIcons.x,
    semanticLabel: semanticLabel,
    onPressed: onPressed,
    color: onCover ? OnVideoColors.foreground : DsTheme.colorsOf(context).textMuted,
  );
}

/// One control at a row's end or over a cover's top-right corner: a bare
/// glyph at the caller's colour, with no fill or edge of its own.
final class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = OnVideoColors.foreground,
  });

  final DsIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsButton.icon(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      size: DsSize.xs,
      variant: DsButtonVariant.ghost,
      icon: DsIcon(icon),
      style: DsButtonStyle(
        height: theme.sizes.xs,
        padding: EdgeInsets.zero,
        background: OnVideoColors.clear,
        foreground: color,
        borderWidth: 0,
        borderRadius: BorderRadius.circular(DsRadii.pill),
        iconSize: theme.sizes.iconXs,
        shadows: const [],
        hovered: const DsButtonStyle(background: OnVideoColors.clear),
        pressed: const DsButtonStyle(background: OnVideoColors.clear),
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
        height: theme.sizes.xs,
        padding: EdgeInsets.symmetric(horizontal: name.isEmpty ? DsSpace.s6 : DsSpace.s8),
        background: OnVideoColors.coverMark,
        foreground: OnVideoColors.foreground,
        // The platform is the first thing the card names: a step above the
        // chips under it.
        textStyle: theme.typography.labelStrong,
        iconSize: theme.sizes.iconSm,
        gap: DsSpace.s6,
      ),
    );
  }
}

/// The broadcast's exception in one pill over a cover or beside a list row's
/// meta line: a recording, the only state a feed cannot take for granted.
final class _StatePill extends StatelessWidget {
  const _StatePill({required this.text});

  /// What the pill says: 回放.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsBadge(
      label: Text(text),
      dot: false,
      style: DsBadgeStyle(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6),
        background: OnVideoColors.coverMark,
        foreground: OnVideoColors.foreground,
        textStyle: theme.typography.caption.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
