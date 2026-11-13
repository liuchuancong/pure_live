import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/page/room_follow.dart' show toggleRoomFollow;
import 'package:pure_live/modules/live/toolbox/direct_link_dialog.dart' show showRoomDirectLinks;
import 'package:pure_live/shared/shared.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The room's details: who is streaming, what is on, the numbers, the room's
/// own facts, and the ways to pass it on.
///
/// The panel is a reading page, not a settings list: one continuous card holds
/// the hero, the title and state, the figures, the notice, the introduction and
/// the room facts; the verbs live in the panel's fixed footer. One surface, so
/// the pieces read as a profile rather than a pile of fragments.
final class RoomDetailsPanel extends ConsumerWidget {
  /// The panel's content.
  const RoomDetailsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(roomProvider);
    final room = state.room;
    if (room == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          Row(
            spacing: DsSpace.s12,
            children: [
              DsSkeleton.circle(size: 44),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s6,
                  children: [DsSkeleton(width: 150, height: 16), DsSkeleton(width: 100, height: 11)],
                ),
              ),
            ],
          ),
          DsSkeleton(width: 260, height: 22),
          DsSkeleton(width: 280, height: 64),
          DsSkeleton(width: 280, height: 88),
        ],
      );
    }
    final notice = room.content.notice?.trim() ?? '';
    final introduction = room.content.introduction?.trim() ?? '';
    final link = roomLinkOf(room);
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final platform = _platformName(ref, room);
    final external = room.links.webUrl?.trim().isNotEmpty == true || room.links.appUrl?.trim().isNotEmpty == true;
    final directLinks = ref.read(sitesProvider).getById(room.ref.platform)?.capability<LivePlaybackProvider>() != null;
    final mobile =
        !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    final opensApp = mobile && (room.links.appUrl?.trim().isNotEmpty ?? false);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(
            child: _Streamer(room: room, platform: platform),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                _TitleBlock(room: room, watchStarted: state.watchStartedAt),
                if (notice.isNotEmpty) _InfoText(label: t.room.notice, text: notice, emphasis: true),
                if (introduction.isNotEmpty && introduction != notice)
                  _InfoText(label: t.room.introduction, text: introduction),
                _RoomInfo(room: room, link: link, onCopy: (label, value) => unawaited(copyRoomValue(context, value))),
                const DsDivider(),
                _Actions(
                  opensApp: opensApp,
                  external: external,
                  directLinks: directLinks,
                  onShare: () => unawaited(shareRoom(context, room)),
                  onOpen: () => unawaited(openRoomExternally(context, room)),
                  onDirectLinks: () => unawaited(showRoomDirectLinks(context, ref, room)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The details card's soft header: an accent wash that marks the identity
/// block without opening a second surface.
final class _Hero extends StatelessWidget {
  const _Hero({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [colors.accent.withValues(alpha: 0.14), colors.accent.withValues(alpha: 0.02)],
        ),
      ),
      child: child,
    );
  }
}

/// The streamer's hero: avatar in its live ring, the name and where the room
/// lives, and the one follow verb. This is the panel's anchor, so it stays at
/// the top and keeps the numbers out of its line.
final class _Streamer extends ConsumerWidget {
  const _Streamer({required this.room, required this.platform});

  final LiveRoom room;
  final String platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final anchorName = (room.anchor?.name ?? '').trim();
    final name = anchorName.isEmpty ? room.content.title : anchorName;
    final avatar = (room.anchor?.avatarUrl ?? room.content.coverUrl).trim();
    final area = (room.area?.areaName ?? '').trim();
    final live = room.broadcast.isLiveNow;
    return Row(
      spacing: DsSpace.s12,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, color: live ? colors.accent : colors.border),
          child: DsAvatar(
            initials: avatarInitials(name),
            image: avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.avatar),
            size: DsSize.lg,
            semanticLabel: name,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s3,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.bodyStrong.copyWith(color: colors.text),
              ),
              Text(
                area.isEmpty ? platform : '$platform · $area',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
        _DetailsFollow(room: room),
      ],
    );
  }
}

/// Follow, in step with the header's pill and the room bar's empty slot.
final class _DetailsFollow extends ConsumerWidget {
  const _DetailsFollow({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final followed = ref.watch(
      followsProvider.select((follows) => follows.rooms.any((entry) => entry.ref.identityKey == room.ref.identityKey)),
    );
    return DsButton(
      variant: followed ? DsButtonVariant.secondary : DsButtonVariant.primary,
      size: DsSize.sm,
      onPressed: () => unawaited(toggleRoomFollow(context, ref)),
      leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: 16),
      child: Text(followed ? t.room.unfollow : t.room.follow),
    );
  }
}

/// The title and the room's current state. The on-air facts are one badge —
/// status, running time and start clock — and the visit's watch time is the
/// next badge, so the two clocks never read as one undifferentiated line.
final class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.room, required this.watchStarted});

  final LiveRoom room;
  final DateTime watchStarted;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final title = room.content.title.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s6,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.title.copyWith(color: colors.text, fontWeight: FontWeight.w600, fontSize: 18),
          ),
        _StateBadges(room: room, watchStarted: watchStarted),
      ],
    );
  }
}

/// The two badges: the broadcast's own state with its running time and start
/// clock on the first line, the visit's watched time on the second, and any
/// restriction after them. A timer keeps the two durations moving.
final class _StateBadges extends StatefulWidget {
  const _StateBadges({required this.room, required this.watchStarted});

  final LiveRoom room;
  final DateTime watchStarted;

  @override
  State<_StateBadges> createState() => _StateBadgesState();
}

final class _StateBadgesState extends State<_StateBadges> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final room = widget.room;
    final startedAt = room.broadcast.startedAt;
    final status = room.broadcast.effectiveLiveStatus;
    final (label, tone) = switch (status) {
      LiveStatus.live => (t.favorites.statusLiveNow, DsStatus.danger),
      LiveStatus.replay => (t.favorites.statusReplay, DsStatus.info),
      _ => (t.favorites.statusOfflineNow, DsStatus.neutral),
    };
    final onAir = startedAt == null
        ? label
        : '$label ${_durationText(startedAt)} · ${t.room.startedAt(time: _startedClock(startedAt))}';
    return Wrap(
      spacing: DsSpace.s6,
      runSpacing: DsSpace.s6,
      children: [
        DsBadge(dot: status == LiveStatus.live, label: Text(onAir), status: tone),
        DsBadge(label: Text('${t.room.statWatched} ${_durationText(widget.watchStarted)}')),
        if (room.broadcast.isRestricted)
          DsBadge(label: Text(_restrictionLabel(t, room.broadcast.effectiveRestriction)), status: DsStatus.danger),
      ],
    );
  }
}

/// The room's own facts — its number and its link, each one line with its
/// copy verb. The broadcast's state is the badge over the title's line, not
/// a fact repeated here.
final class _RoomInfo extends StatelessWidget {
  const _RoomInfo({required this.room, required this.link, required this.onCopy});

  final LiveRoom room;
  final String link;
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final facts = <(String, String)>[
      (t.room.roomNumber, room.ref.roomId),
      if (link.isNotEmpty) (t.room.link, _withoutScheme(link)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        for (final (label, value) in facts) _FactCell(label: label, value: value, onCopy: () => onCopy(label, value)),
      ],
    );
  }
}

/// One fact: a small caption over its value, with the copy verb only where
/// there is something worth copying.
final class _FactCell extends StatelessWidget {
  const _FactCell({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s4,
      children: [
        Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
        Row(
          spacing: DsSpace.s4,
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.text),
              ),
            ),
            if (onCopy != null)
              DsTooltip(
                message: '${t.room.copy} $label',
                child: DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.xs,
                  semanticLabel: '${t.room.copy} $label',
                  onPressed: onCopy,
                  icon: const DsIcon(DsIcons.copy, size: 13),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Notice or introduction, as a quiet reading block rather than a settings
/// section: the notice takes the accent edge, the introduction stays neutral.
/// Long copy folds to two lines; the expand verb keeps the panel one screen.
final class _InfoText extends StatefulWidget {
  const _InfoText({required this.label, required this.text, this.emphasis = false});

  final String label;
  final String text;
  final bool emphasis;

  @override
  State<_InfoText> createState() => _InfoTextState();
}

final class _InfoTextState extends State<_InfoText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = theme.typography.body.copyWith(color: colors.textMuted, height: 1.6);
    final leading = widget.emphasis ? DsSpace.s12 : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth - leading);
        final canExpand = painter.didExceedMaxLines;
        return Container(
          padding: EdgeInsetsDirectional.only(start: leading),
          decoration: widget.emphasis
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: colors.accent, width: 3)),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s4,
            children: [
              Text(
                widget.label,
                style: theme.typography.caption.copyWith(
                  color: widget.emphasis ? colors.text : colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.text,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: style,
              ),
              if (canExpand)
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.xs,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? t.room.collapse : t.room.expand),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The panel's verbs: share, open where the platform shows it, and the stream's
/// own address. One equal-width tile each, so the row reads as a group rather
/// than three buttons that happened to land together.
final class _Actions extends StatelessWidget {
  const _Actions({
    required this.opensApp,
    required this.external,
    required this.directLinks,
    required this.onShare,
    required this.onOpen,
    required this.onDirectLinks,
  });

  final bool opensApp;
  final bool external;
  final bool directLinks;
  final VoidCallback onShare;
  final VoidCallback onOpen;
  final VoidCallback onDirectLinks;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget button(DsIconData icon, String label, VoidCallback onPressed) => DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      leading: DsIcon(icon, size: 15),
      onPressed: onPressed,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return Row(
      spacing: DsSpace.s8,
      children: [
        Expanded(child: button(DsIcons.share2, t.room.share, onShare)),
        if (external) Expanded(child: button(DsIcons.externalLink, opensApp ? t.room.openApp : t.room.openWeb, onOpen)),
        if (directLinks) Expanded(child: button(DsIcons.link2, t.toolbox.linkDirect, onDirectLinks)),
      ],
    );
  }
}

/// Copies [value] and says so.
Future<void> copyRoomValue(BuildContext context, String value) async {
  if (value.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) showDsToast(context: context, title: context.t.room.copied);
}

/// Copies the room's own link (the web page, else the share link).
Future<void> copyRoomLink(BuildContext context, LiveRoom room) => copyRoomValue(context, roomLinkOf(room));

/// The room's link as the app hands it out: its web page first, then the
/// platform's share link.
String roomLinkOf(LiveRoom room) {
  for (final candidate in [room.links.webUrl, room.links.shareUrl]) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Shares [room] through the system sheet where one exists, else copies
/// its link (and with no link at all, says the share failed).
Future<void> shareRoom(BuildContext context, LiveRoom room) async {
  final title = room.content.title.trim();
  final link = roomLinkOf(room);
  final text = [title, link].where((part) => part.isNotEmpty).join('\n');
  if (text.isEmpty) {
    if (context.mounted) showDsToast(context: context, title: context.t.room.shareFailed);
    return;
  }
  final platform = defaultTargetPlatform;
  final sheet =
      !kIsWeb &&
      (platform == TargetPlatform.android ||
          platform == TargetPlatform.iOS ||
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows);
  if (sheet) {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: title.isEmpty ? null : title));
      return;
    } on Object {
      // A platform without a usable sheet falls through to the clipboard.
    }
  }
  if (!context.mounted) return;
  await copyRoomValue(context, link.isEmpty ? text : link);
}

/// Opens [room] where the platform itself shows it: the app's own scheme on
/// a phone first, then the web page; on a desktop the web page.
Future<void> openRoomExternally(BuildContext context, LiveRoom room) async {
  final t = context.t;
  final web = room.links.webUrl?.trim() ?? '';
  final app = room.links.appUrl?.trim() ?? '';
  if (web.isEmpty && app.isEmpty) {
    showDsToast(context: context, title: t.room.openUnavailable);
    return;
  }
  final mobile =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  var opened = false;
  if (mobile && app.isNotEmpty) opened = await _launch(app);
  if (!opened && web.isNotEmpty) opened = await _launch(web);
  if (!opened && context.mounted) showDsToast(context: context, title: t.room.openFailed);
}

Future<bool> _launch(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

String _platformName(WidgetRef ref, LiveRoom room) {
  final site = ref.read(sitesProvider).getById(room.ref.platform);
  return site == null ? room.ref.platform : localizedSiteName(site);
}

String _startedClock(DateTime startedAt) {
  final local = startedAt.toLocal();
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  return sameDay ? time : '${two(local.month)}-${two(local.day)} $time';
}

String _withoutScheme(String link) => link.replaceFirst(RegExp('^https?://'), '');

String _durationText(DateTime? since) {
  if (since == null) return '—';
  final elapsed = DateTime.now().difference(since);
  if (elapsed.isNegative) return '00:00:00';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(elapsed.inHours)}:${two(elapsed.inMinutes.remainder(60))}:${two(elapsed.inSeconds.remainder(60))}';
}

/// What keeps the room from playing, in the viewer's language.
String _restrictionLabel(Translations t, LiveRestriction restriction) => switch (restriction) {
  LiveRestriction.needsLogin => t.room.restrictionNeedsLogin,
  LiveRestriction.paid => t.room.restrictionPaid,
  LiveRestriction.subscribersOnly => t.room.restrictionSubscribersOnly,
  LiveRestriction.private => t.room.restrictionPrivate,
  LiveRestriction.appOnly => t.room.restrictionAppOnly,
  LiveRestriction.regionBlocked => t.room.restrictionRegionBlocked,
  LiveRestriction.password => t.room.restrictionPassword,
  LiveRestriction.adult => t.room.restrictionAdult,
  LiveRestriction.unplayable || LiveRestriction.none => t.room.restrictionUnplayable,
};
