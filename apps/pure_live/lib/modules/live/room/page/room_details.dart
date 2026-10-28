import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// Opens the room details: the reference's "直播间详情" laid over the page,
/// never over the picture. Everything a viewer may want to know about the
/// room and do about it lives here — the streamer and the way back to the
/// platform, the state and the full title, the figures, the notice and the
/// introduction, the room number and the link, plus share and open.
Future<void> showRoomDetails(BuildContext context) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(title: Text(context.t.room.details), child: const RoomDetailsPanel()),
);

/// The details panel's content; the page's info strip and menu open it.
final class RoomDetailsPanel extends ConsumerWidget {
  /// The panel's content.
  const RoomDetailsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final room = ref.watch(roomProvider).room;
    if (room == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsSkeleton(width: 220, height: 40),
          DsSkeleton(width: 320, height: 16),
          DsSkeleton(width: 260, height: 16),
        ],
      );
    }
    final title = room.content.title.trim();
    final notice = room.content.notice?.trim() ?? '';
    final introduction = room.content.introduction?.trim() ?? '';
    final link = roomLinkOf(room);
    final external = room.links.webUrl?.trim().isNotEmpty == true || room.links.appUrl?.trim().isNotEmpty == true;
    final platform = _platformName(ref, room);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        _Streamer(room: room, platform: platform),
        _State(room: room),
        if (title.isNotEmpty) Text(title, style: DsTheme.of(context).typography.title.copyWith(color: colors.text)),
        _Figures(room: room),
        if (notice.isNotEmpty) _TextSection(label: t.room.notice, text: notice),
        if (introduction.isNotEmpty && introduction != notice)
          _TextSection(label: t.room.introduction, text: introduction),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s4,
          children: [
            _CopyRow(
              icon: DsIcons.hash,
              label: t.room.roomNumber,
              value: room.ref.roomId,
              onCopy: () => unawaited(copyRoomValue(context, room.ref.roomId)),
            ),
            if (link.isNotEmpty)
              _CopyRow(
                icon: DsIcons.link,
                label: t.room.link,
                value: _withoutScheme(link),
                onCopy: () => unawaited(copyRoomValue(context, link)),
              ),
          ],
        ),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            DsButton(
              variant: DsButtonVariant.secondary,
              leading: const DsIcon(DsIcons.share, size: 16),
              onPressed: () => unawaited(shareRoom(context, room)),
              child: Text(t.room.share),
            ),
            if (external)
              DsButton(
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.externalLink, size: 16),
                onPressed: () => unawaited(openRoomExternally(context, room)),
                child: Text(t.room.openIn(platform: platform)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The streamer, the platform and the area, with the follow action.
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
    return Row(
      spacing: DsSpace.s12,
      children: [
        DsAvatar(
          initials: name,
          image: avatar.isEmpty ? null : cachedImage(avatar),
          size: DsSize.md,
          semanticLabel: name,
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
                style: theme.typography.heading.copyWith(color: colors.text),
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

/// The follow action of the details panel, in step with the app bar's.
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
      onPressed: () => unawaited(ref.read(roomProvider.notifier).toggleFollow()),
      leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: 16),
      child: Text(followed ? t.room.unfollow : t.room.follow),
    );
  }
}

/// The room's state: live, replay or offline, and when it started.
final class _State extends StatelessWidget {
  const _State({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final startedAt = room.broadcast.startedAt;
    final (label, status) = switch (room.broadcast.effectiveLiveStatus) {
      LiveStatus.live => (t.favorites.statusLiveNow, DsStatus.danger),
      LiveStatus.replay => (t.favorites.statusReplay, DsStatus.info),
      _ => (t.favorites.statusOfflineNow, DsStatus.neutral),
    };
    return Wrap(
      spacing: DsSpace.s8,
      runSpacing: DsSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DsBadge(dot: false, label: Text(label), status: status),
        if (startedAt != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(DsIcons.clock, size: theme.sizes.iconXs, color: colors.textSubtle),
              Text(
                t.room.startedAt(time: _startedClock(startedAt)),
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        if (room.broadcast.isRestricted)
          DsBadge(
            dot: false,
            label: Text(_restrictionLabel(t, room.broadcast.effectiveRestriction)),
            status: DsStatus.danger,
          ),
      ],
    );
  }
}

/// The figures the room's source gave, each named for what it means.
final class _Figures extends StatelessWidget {
  const _Figures({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final figures = <(DsIconData, String, int)>[
      if (room.audience.onlineViewers case final value?) (DsIcons.eye, t.room.onlineViewers, value),
      if (room.audience.popularity case final value?) (DsIcons.flame, t.room.popularity, value),
      if (room.audience.totalViewers case final value?) (DsIcons.users, t.room.totalViewers, value),
    ];
    if (figures.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: DsSpace.s16,
      runSpacing: DsSpace.s6,
      children: [
        for (final (icon, label, value) in figures)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(icon, size: theme.sizes.iconXs, color: colors.textSubtle),
              Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
              Text(
                AudienceFormat.format(value),
                style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
              ),
            ],
          ),
      ],
    );
  }
}

/// Notice or introduction: a titled card whose text wraps in full.
final class _TextSection extends StatelessWidget {
  const _TextSection({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsListSection(
      header: Text(label),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s12),
          child: Text(text, style: theme.typography.body.copyWith(color: colors.textMuted)),
        ),
      ],
    );
  }
}

/// One copyable fact: its name, its value and a copy button.
final class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.icon, required this.label, required this.value, required this.onCopy});

  final DsIconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsListRow(
      leading: DsIcon(icon),
      title: Text(label),
      description: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: DsButton.icon(
        variant: DsButtonVariant.ghost,
        size: DsSize.sm,
        semanticLabel: '${t.room.copy} $label',
        onPressed: onCopy,
        icon: const DsIcon(DsIcons.copy, size: 16),
      ),
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
