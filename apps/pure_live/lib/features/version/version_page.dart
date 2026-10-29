import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/features/version/release_builds.dart';
import 'package:pure_live/features/version/update_download.dart' show showUpdateDownload;
import 'package:pure_live/features/version/update_feed.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// 查看更新: what the new release says and the two ways to act on it.
///
/// A dialog rather than a page because the decision is short — read the
/// notes, take the installer or leave it — and the viewer stays on the
/// version page either way.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDsDialog<void>(
    context: context,
    builder: (context) => _UpdateDialog(info: info),
  );
}

final class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final notes = plainReleaseText(info.log);
    return DsDialog(
      title: Text(t.settings.updatePanelTitle),
      icon: const DsIcon(DsIcons.refreshCw),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              Text(info.version, style: theme.typography.heading.copyWith(color: colors.text)),
              if (info.prerelease) DsBadge(dot: false, label: Text(t.settings.prerelease), status: DsStatus.warning),
              const Spacer(),
              Text(
                t.settings.updateBuild(build: '${info.buildNumber}'),
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
            ],
          ),
          if (notes.isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                child: Text(notes, style: theme.typography.body.copyWith(color: colors.textMuted)),
              ),
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.settings.updateLater),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(showDownloadPage(context, version: info.version));
          },
          child: Text(t.settings.downloadOtherBuilds),
        ),
        DsButton(
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(_downloadRecommended(context, version: info.version, fallback: info.downloadUrl));
          },
          child: Text(t.settings.downloadInstaller),
        ),
      ],
    );
  }
}

/// 获取安装包: every package the release publishes, this platform's first.
Future<void> showDownloadPage(BuildContext context, {String? version}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(builder: (context) => ReleaseDownloadsPage(version: version)));
}

/// 历史版本: the published releases, newest first, each with its notes and
/// its own download page. A page rather than a panel because the notes are
/// long and reading them is the point.
Future<void> showReleaseHistory(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(builder: (context) => const ReleaseHistoryPage()));
}

/// The download page.
final class ReleaseDownloadsPage extends ConsumerStatefulWidget {
  /// The page for [version] (the latest release when empty).
  const ReleaseDownloadsPage({this.version, super.key});

  /// The version whose release is listed.
  final String? version;

  @override
  ConsumerState<ReleaseDownloadsPage> createState() => _ReleaseDownloadsPageState();
}

final class _ReleaseDownloadsPageState extends ConsumerState<ReleaseDownloadsPage> {
  late Future<List<ReleaseBuild>> _future = _load();

  Future<List<ReleaseBuild>> _load() {
    final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
    return fetchReleaseBuilds(http, version: widget.version);
  }

  void _retry() => setState(() => _future = _load());

  Future<void> _download(ReleaseBuild build) async {
    await showUpdateDownload(context, build: build);
    if (mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final own = currentReleasePlatform();
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageBar(
              title: t.settings.downloadTitle,
              subtitle: widget.version == null ? t.settings.downloadLatest : 'v${widget.version}',
              onBack: () => Navigator.of(context).pop(),
              onRefresh: _retry,
              refreshLabel: t.settings.cacheRefresh,
            ),
            Expanded(
              child: FutureBuilder<List<ReleaseBuild>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
                  }
                  if (snapshot.hasError) {
                    return _LoadFailed(
                      message: '${snapshot.error}',
                      retryLabel: t.common.retry,
                      title: t.settings.downloadFailed,
                      onRetry: _retry,
                      onOpen: () => unawaited(_open(context, releasePageUrl(widget.version ?? ''))),
                      openLabel: t.settings.openDownload,
                    );
                  }
                  final builds = snapshot.data ?? const <ReleaseBuild>[];
                  if (builds.isEmpty) {
                    return DsEmptyState(icon: const DsIcon(DsIcons.package), title: Text(t.settings.downloadEmpty));
                  }
                  final recommended = recommendedBuild(builds);
                  // This platform's packages first, then everything else in
                  // the release's own order: the viewer came for one file.
                  final ordered = [
                    ...builds.where((build) => build.platform == own),
                    ...builds.where((build) => build.platform != own),
                  ];
                  return ListView(
                    padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.s8),
                        child: Text(
                          t.settings.downloadHint,
                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                        ),
                      ),
                      DsListSection(
                        children: [
                          for (final build in ordered)
                            DsListRow(
                              leading: DsIcon(build.platform == own ? DsIcons.monitorSmartphone : DsIcons.package),
                              title: Text(build.name),
                              description: Text(
                                [
                                  releasePlatformLabel(t, build.platform),
                                  if (build.arch.isNotEmpty) build.arch,
                                  releaseKindLabel(t, build.kind),
                                  formatReleaseSize(build.size),
                                  t.settings.downloadCount(count: build.downloads),
                                ].join(' · '),
                              ),
                              trailing: DsButton(
                                variant: build == recommended ? DsButtonVariant.primary : DsButtonVariant.secondary,
                                size: DsSize.sm,
                                onPressed: () => unawaited(_download(build)),
                                child: Text(t.settings.downloadAction),
                              ),
                            ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.only(top: DsSpace.s8),
                          child: DsButton(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            leading: const DsIcon(DsIcons.externalLink, size: 16),
                            onPressed: () => unawaited(_open(context, releasePageUrl(builds.first.version))),
                            child: Text(t.settings.openReleasePage),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The release history page.
final class ReleaseHistoryPage extends ConsumerStatefulWidget {
  /// The page.
  const ReleaseHistoryPage({super.key});

  @override
  ConsumerState<ReleaseHistoryPage> createState() => _ReleaseHistoryPageState();
}

final class _ReleaseHistoryPageState extends ConsumerState<ReleaseHistoryPage> {
  late Future<List<ReleaseInfo>> _future = _load();
  final Set<String> _expanded = <String>{};

  Future<List<ReleaseInfo>> _load() {
    final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
    return fetchReleases(http);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageBar(
              title: t.settings.releaseHistory,
              subtitle: t.settings.releaseHistoryDesc,
              onBack: () => Navigator.of(context).pop(),
              onRefresh: _retry,
              refreshLabel: t.settings.cacheRefresh,
            ),
            Expanded(
              child: FutureBuilder<List<ReleaseInfo>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
                  }
                  if (snapshot.hasError) {
                    return _LoadFailed(
                      message: '${snapshot.error}',
                      retryLabel: t.common.retry,
                      title: t.settings.releaseHistoryFailed,
                      onRetry: _retry,
                      onOpen: () => unawaited(_open(context, versionProjectUrl)),
                      openLabel: t.settings.openDownload,
                    );
                  }
                  final releases = snapshot.data ?? const <ReleaseInfo>[];
                  if (releases.isEmpty) {
                    return DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.settings.releaseHistoryEmpty));
                  }
                  return ListView(
                    padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, DsSpace.s24),
                    children: [
                      for (final release in releases)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.s12),
                          child: DsCard(
                            child: Padding(
                              padding: const EdgeInsets.all(DsSpace.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: DsSpace.s8,
                                children: [
                                  Row(
                                    spacing: DsSpace.s8,
                                    children: [
                                      Text(
                                        release.version,
                                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                                      ),
                                      if (release.date.isNotEmpty)
                                        Text(
                                          release.date,
                                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                        ),
                                      const Spacer(),
                                      if (release.url.isNotEmpty)
                                        DsButton(
                                          variant: DsButtonVariant.ghost,
                                          size: DsSize.sm,
                                          onPressed: () =>
                                              unawaited(showDownloadPage(context, version: release.version)),
                                          child: Text(t.settings.downloadTitle),
                                        ),
                                      DsButton(
                                        variant: DsButtonVariant.ghost,
                                        size: DsSize.sm,
                                        leading: const DsIcon(DsIcons.externalLink, size: 14),
                                        onPressed: () => unawaited(
                                          _open(
                                            context,
                                            release.url.isEmpty ? releasePageUrl(release.version) : release.url,
                                          ),
                                        ),
                                        child: Text(t.settings.openReleasePage),
                                      ),
                                    ],
                                  ),
                                  if (release.author.isNotEmpty)
                                    Text(
                                      release.author,
                                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                                    ),
                                  if (plainReleaseText(release.changelog) case final notes when notes.isNotEmpty) ...[
                                    Text(
                                      notes,
                                      maxLines: _expanded.contains(release.version) ? null : 6,
                                      overflow: _expanded.contains(release.version)
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style: theme.typography.body.copyWith(color: colors.textMuted),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional.centerStart,
                                      child: DsButton(
                                        variant: DsButtonVariant.ghost,
                                        size: DsSize.sm,
                                        onPressed: () => setState(() {
                                          if (!_expanded.remove(release.version)) _expanded.add(release.version);
                                        }),
                                        child: Text(
                                          _expanded.contains(release.version)
                                              ? t.settings.releaseCollapse
                                              : t.settings.releaseExpand,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Takes the recommended package for this device and downloads it, opening the
/// release page when the release carries nothing the app can install.
Future<void> _downloadRecommended(BuildContext context, {required String version, required String fallback}) async {
  final t = context.t;
  final http = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(networkFactoryProvider).create(profile: ClientProfile.api);
  final page = fallback.isEmpty ? releasePageUrl(version) : fallback;
  try {
    final builds = await fetchReleaseBuilds(http, version: version);
    final recommended = recommendedBuild(builds);
    if (!context.mounted) return;
    if (recommended == null) {
      showDsToast(context: context, title: t.settings.downloadNoBuild);
      await _open(context, page);
      return;
    }
    await showUpdateDownload(context, build: recommended);
  } on Object {
    if (!context.mounted) return;
    await _open(context, page);
  }
}

/// The pages' shared top bar: back, title and subtitle, refresh.
final class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
    required this.refreshLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final String refreshLabel;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s4),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            semanticLabel: context.t.common.back,
            onPressed: onBack,
            icon: const DsIcon(DsIcons.chevronLeft),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.typography.title.copyWith(color: colors.text)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
              ],
            ),
          ),
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            semanticLabel: refreshLabel,
            onPressed: onRefresh,
            icon: const DsIcon(DsIcons.refreshCw),
          ),
        ],
      ),
    );
  }
}

/// A feed that would not read: why, retry, and the page to do it by hand.
final class _LoadFailed extends StatelessWidget {
  const _LoadFailed({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.openLabel,
    required this.onRetry,
    required this.onOpen,
  });

  final String title;
  final String message;
  final String retryLabel;
  final String openLabel;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: DsSpace.s12,
          children: [
            DsIcon(DsIcons.cloudOff, size: 32, color: colors.textSubtle),
            Text(title, style: theme.typography.bodyStrong.copyWith(color: colors.text)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: DsSpace.s8,
              children: [
                DsButton(variant: DsButtonVariant.secondary, onPressed: onRetry, child: Text(retryLabel)),
                DsButton(onPressed: onOpen, child: Text(openLabel)),
              ],
            ),
          ],
        ),
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
  text = text.replaceAll(RegExp(r'^\s*\|.*\|\s*$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*([-*_]\s*){3,}$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}
