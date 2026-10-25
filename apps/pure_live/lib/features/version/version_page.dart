import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/features/version/update_feed.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/app_loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// Opens one release's page: what changed, its build, and the way to the
/// download page. Nothing installs from here — the release address is the
/// platform's own page, as the reference's version page also ends.
Future<void> showUpdatePanel(BuildContext context, UpdateInfo info) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(
    title: Text(context.t.settings.updatePanelTitle),
    child: _UpdatePanel(info: info),
  ),
);

final class _UpdatePanel extends StatelessWidget {
  const _UpdatePanel({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final url = info.downloadUrl.isNotEmpty ? info.downloadUrl : versionProjectUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Text(info.version, style: theme.typography.heading.copyWith(color: colors.text)),
            if (info.prerelease)
              DsBadge(dot: false, label: Text(t.settings.updatePanelTitle), status: DsStatus.warning),
            const Spacer(),
            Text(
              t.settings.updateBuild(build: '${info.buildNumber}'),
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
          ],
        ),
        if (info.log.isNotEmpty)
          DsListSection(
            children: [
              Padding(
                padding: const EdgeInsets.all(DsSpace.s12),
                child: Text(plainReleaseText(info.log), style: theme.typography.body.copyWith(color: colors.textMuted)),
              ),
            ],
          ),
        DsButton(
          leading: const DsIcon(DsIcons.externalLink, size: 16),
          onPressed: () => unawaited(_open(context, url)),
          child: Text(t.settings.openDownload),
        ),
      ],
    );
  }
}

/// The release history, read when the panel opens: one card per release,
/// newest first, with its notes and its page.
Future<void> showReleaseHistory(BuildContext context) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(title: Text(context.t.settings.releaseHistory), child: const _ReleaseHistory()),
);

final class _ReleaseHistory extends ConsumerStatefulWidget {
  const _ReleaseHistory();

  @override
  ConsumerState<_ReleaseHistory> createState() => _ReleaseHistoryState();
}

final class _ReleaseHistoryState extends ConsumerState<_ReleaseHistory> {
  late Future<List<ReleaseInfo>> _future = _load();

  Future<List<ReleaseInfo>> _load() {
    final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
    return fetchReleases(http);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return FutureBuilder<List<ReleaseInfo>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: AppLoadingIndicator(size: 24));
        }
        if (snapshot.hasError) {
          return DsEmptyState(
            icon: const DsIcon(DsIcons.info),
            title: Text(t.settings.releaseHistoryFailed),
            description: Text('${snapshot.error}'),
            actions: [DsButton(onPressed: _retry, child: Text(t.common.retry))],
          );
        }
        final releases = snapshot.data ?? const <ReleaseInfo>[];
        if (releases.isEmpty) {
          return DsEmptyState(icon: const DsIcon(DsIcons.info), title: Text(t.settings.releaseHistoryEmpty));
        }
        return DsListSection(children: [for (final release in releases) _ReleaseRow(release: release)]);
      },
    );
  }
}

/// One release row: version and date, the author, the notes in plain text
/// and the release page.
final class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.release});

  final ReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final notes = plainReleaseText(release.changelog);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              Text(release.version, style: theme.typography.bodyStrong.copyWith(color: colors.text)),
              if (release.title.isNotEmpty && release.title != release.version)
                Expanded(
                  child: Text(
                    release.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                )
              else
                const Spacer(),
              if (release.date.isNotEmpty)
                Text(
                  t.settings.releasedOn(date: release.date),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
            ],
          ),
          if (release.author.isNotEmpty)
            Text(release.author, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          if (notes.isNotEmpty)
            Text(
              notes,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(color: colors.textMuted),
            ),
          if (release.url.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.externalLink, size: 16),
                onPressed: () => unawaited(_open(context, release.url)),
                child: Text(t.settings.openDownload),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens [url] in the platform's browser; a failure says so rather than
/// leaving the press silent.
Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showDsToast(context: context, title: context.t.settings.updateCheckFailed);
  }
}

/// The feed's Markdown reduced to the words a plain text block can show:
/// headings and emphasis lose their marks, links keep their labels, list
/// items keep a bullet. Images and rules leave. A full renderer would need
/// a package this app does not carry; the notes stay readable regardless.
String plainReleaseText(String markdown) {
  var text = markdown;
  text = text.replaceAllMapped(RegExp(r'!\[[^\]]*\]\([^)]*\)'), (_) => '');
  text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (match) => match[1] ?? '');
  text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
  text = text.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
  text = text.replaceAllMapped(RegExp(r'[*_]{1,3}([^*_\n]+)[*_]{1,3}'), (match) => match[1] ?? '');
  text = text.replaceAll('`', '');
  text = text.replaceAll(RegExp(r'^\s*([-*_]\s*){3,}$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}
