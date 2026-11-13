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
            padding: EdgeInsetsDirectional.fromSTEB(
              MediaQuery.sizeOf(context).width < 480 ? DsSpace.s12 : DsSpace.s16,
              DsSpace.s8,
              MediaQuery.sizeOf(context).width < 480 ? DsSpace.s12 : DsSpace.s16,
              DsSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                _RoomFactsList(room: room, watchStarted: state.watchStartedAt),
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

/// The room's facts as the component library's own list: the title, the
/// notice and the introduction under their own rows, the broadcast's start
/// clock and elapsed time, this visit's watch time, and the room's number
/// and link — the number and the link copy on a press. A timer keeps the
/// two durations moving; a restriction, when the stream carries one, keeps
/// its badge.
final class _RoomFactsList extends StatefulWidget {
  const _RoomFactsList({required this.room, required this.watchStarted});

  final LiveRoom room;
  final DateTime watchStarted;

  @override
  State<_RoomFactsList> createState() => _RoomFactsListState();
}

final class _RoomFactsListState extends State<_RoomFactsList> {
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
    final title = room.content.title.trim();
    final notice = room.content.notice?.trim() ?? '';
    final introduction = room.content.introduction?.trim() ?? '';
    final link = roomLinkOf(room);
    // The title's own words ride under the row name: a long name wraps
    // instead of squeezing into the end-side value slot.
    const prose = DsListRowStyle(maxLines: 8);
    // The live room's lists run at the library's own measure: the app's
    // settings-sized rows and paddings stop at this subtree.
    final theme = DsTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        DsListRowTheme(
          data: DsListRowThemeData(style: DsListRow.defaultStyle(theme)),
          child: DsListSectionTheme(
            data: DsListSectionThemeData(style: DsListSection.defaultStyle(theme)),
            child: DsListSection(
              children: [
                if (title.isNotEmpty)
                  DsListRow(
                    title: Text(t.room.titleLabel),
                    // The stream's own name, not a text document's: the camera,
                    // not the letter T.
                    leading: const DsIcon(DsIcons.video),
                    description: Text(title),
                    style: prose,
                  ),
                if (startedAt != null) ...[
                  DsListRow(
                    title: Text(t.room.startTime),
                    leading: const DsIcon(DsIcons.clock),
                    detail: Text(_startedClock(startedAt)),
                  ),
                  DsListRow(
                    title: Text(t.room.statWatched),
                    leading: const DsIcon(DsIcons.hourglass),
                    detail: Text(_durationText(startedAt)),
                  ),
                ],
                DsListRow(
                  title: Text(t.room.watchDuration),
                  leading: const DsIcon(DsIcons.eye),
                  detail: Text(_durationText(widget.watchStarted)),
                ),
                DsListRow(
                  title: Text(t.room.roomNumber),
                  leading: const DsIcon(DsIcons.hash),
                  detail: Text(room.ref.roomId),
                  onPressed: () => unawaited(copyRoomValue(context, room.ref.roomId)),
                ),
                if (link.isNotEmpty)
                  DsListRow(
                    title: Text(t.room.link),
                    leading: const DsIcon(DsIcons.link2),
                    detail: Text(_withoutScheme(link)),
                    onPressed: () => unawaited(copyRoomValue(context, link)),
                  ),
              ],
            ),
          ),
        ),
        if (notice.isNotEmpty) _RoomProseCard(icon: DsIcons.megaphone, label: t.room.notice, text: notice),
        if (introduction.isNotEmpty && introduction != notice)
          _RoomProseCard(icon: DsIcons.fileText, label: t.room.introduction, text: introduction),
        if (room.broadcast.isRestricted)
          Wrap(
            children: [
              DsBadge(label: Text(_restrictionLabel(t, room.broadcast.effectiveRestriction)), status: DsStatus.danger),
            ],
          ),
      ],
    );
  }
}

/// A notice or an introduction as the component library's card: the row name
/// under its icon, the words wrapping freely — no list row's line cap.
final class _RoomProseCard extends StatelessWidget {
  const _RoomProseCard({required this.icon, required this.label, required this.text});

  final DsIconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s6,
        children: [
          Row(
            spacing: DsSpace.s6,
            children: [
              DsIcon(icon, size: 14, color: colors.textMuted),
              Text(
                label,
                style: theme.typography.caption.copyWith(color: colors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(text, style: theme.typography.body.copyWith(color: colors.text, height: 1.6)),
        ],
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          button(DsIcons.share2, t.room.share, onShare),
          if (external) button(DsIcons.externalLink, opensApp ? t.room.openApp : t.room.openWeb, onOpen),
          if (directLinks) button(DsIcons.link2, t.toolbox.linkDirect, onDirectLinks),
        ];
        if (constraints.maxWidth < 420) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s8, children: tiles);
        }
        return Row(
          spacing: DsSpace.s8,
          children: [for (final tile in tiles) Expanded(child: tile)],
        );
      },
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
