import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/about/app_update_flow.dart';
import 'package:pure_live/features/about/markdown_text.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/features/about/version_controller.dart' show versionControllerProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_surface.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The version-history presentation (3.x `VersionHistoryPage`): the release
/// list beside its changelog detail, refreshed from the update feed.
///
/// The reference presents this as a routed page — wide screens get a
/// two-pane layout, narrow ones a list whose rows open a detail dialog. The
/// app's routes own no history page, so the same presentation runs as a
/// sheet: two panes when the sheet is wide, list + dialog when narrow.
///
/// The changelog detail carries the reference's download-files section: the
/// release's published files, each with its size and download count and
/// copy/download actions — downloading hands the file's URL to the system
/// browser, the app ships no download pipeline of its own.

/// Opens the history as a floating surface: centred on a desktop window, rising
/// from the bottom edge on a handheld.
Future<void> showVersionHistorySheet(
  BuildContext context,
  WidgetRef ref, {
  required List<AppRelease> releases,
  required Future<List<AppRelease>?> Function() refresh,
}) {
  return showSettingsSurface<void>(
    context,
    ref.settingsFormFactor,
    title: null,
    // The height is the list's own budget: the surface scrolls on the phone and
    // caps on the desktop, and an unbounded `ListView.separated` asserts in the
    // first of those.
    body: (surfaceContext) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(surfaceContext).height * 0.65),
      child: VersionHistorySheet(releases: releases, refresh: refresh),
    ),
  );
}

/// The sheet's content: a header with the refresh action over the list
/// (plus detail pane when wide).
final class VersionHistorySheet extends StatefulWidget {
  /// Shows [releases], refreshed through [refresh].
  const new({required this.releases, required this.refresh, super.key});

  /// The releases known when the sheet opened.
  final List<AppRelease> releases;

  /// Re-reads the feed; null keeps the list already shown (a failed refresh
  /// never blanks the history).
  final Future<List<AppRelease>?> Function() refresh;

  @override
  State<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

final class _VersionHistorySheetState extends State<VersionHistorySheet> {
  late List<AppRelease> _releases = List.of(widget.releases);
  int _selected = 0;
  bool _loading = false;

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      final releases = await widget.refresh();
      if (!mounted || releases == null || releases.isEmpty) {
        return;
      }
      setState(() {
        _releases = releases;
        if (_selected >= _releases.length) {
          _selected = 0;
        }
      });
    } on Object {
      // A failed refresh keeps the list already shown; the spinner stops in
      // the finally block and the user can retry.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openRelease(AppRelease release) => openReleasePage(context, release);

  String _date(AppRelease release) => release.publishedAt?.toLocal().toString().split(' ').first ?? '—';

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(PureSpacing.lg, 0, PureSpacing.lg, PureSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PureSpacing.xs, PureSpacing.sm, PureSpacing.xs, PureSpacing.md),
            child: Row(
              children: [
                Expanded(child: Text(context.t.about.versionHistory, style: theme.text.title)),
                PureIconButton(
                  tooltip: context.t.about.refresh,
                  icon: Icons.refresh,
                  onPressed: _loading ? null : _refresh,
                ),
              ],
            ),
          ),
          if (_loading) const PureProgress(value: null, height: 2),
          Expanded(
            child: _releases.isEmpty
                ? PureEmpty(title: context.t.common.empty)
                : PureAdaptiveLayout(
                    child: _list(context, wide: false),
                    tablet: (context, list) {
                      final wideList = _list(context, wide: true);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 300, child: wideList),
                          const SizedBox(width: PureSpacing.lg),
                          Expanded(child: _detailPane(context, _releases[_selected.clamp(0, _releases.length - 1)])),
                        ],
                      );
                    },
                    desktop: (context, list) {
                      final wideList = _list(context, wide: true);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 300, child: wideList),
                          const SizedBox(width: PureSpacing.lg),
                          Expanded(child: _detailPane(context, _releases[_selected.clamp(0, _releases.length - 1)])),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, {required bool wide}) {
    final theme = PureTheme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.only(top: PureSpacing.xs, bottom: PureSpacing.sm),
      itemCount: _releases.length,
      separatorBuilder: (context, index) => const SizedBox(height: PureSpacing.sm),
      itemBuilder: (context, index) {
        final release = _releases[index];
        final current = index == _selected;
        return PureBox(
          // The hover and press layer sits behind the card's own fill, which is
          // translucent — ink would need a Material ancestor the Fluent dialog
          // that hosts this list does not have.
          style: (state) => Style(
            borderRadius: BorderRadius.circular(16),
            background: switch (state) {
              InteractionState.pressed => theme.colors.fillTertiary,
              InteractionState.hovered => theme.colors.fillQuaternary,
              _ => null,
            },
          ),
          onTap: () {
            if (wide) {
              setState(() => _selected = index);
            } else {
              unawaited(_showDetails(context, release));
            }
          },
          child: AnimatedContainer(
            duration: theme.duration,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: !wide || current
                  ? (current
                        ? theme.colors.primaryBg.withValues(alpha: 0.6)
                        : theme.colors.fillSecondary.withValues(alpha: 0.35))
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: current && wide ? theme.colors.primary : theme.colors.border.withValues(alpha: 0.3),
                width: current && wide ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current ? theme.colors.primary : theme.colors.border,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        release.tag.startsWith('v') ? release.tag : 'v${release.tag}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: current && wide ? theme.colors.primaryText : theme.colors.text,
                        ),
                      ),
                      const SizedBox(height: PureSpacing.xxs),
                      Text(
                        _date(release),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: theme.colors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The wide layout's inline detail: the release identity with its
  /// open-release action over the changelog.
  Widget _detailPane(BuildContext context, AppRelease release) {
    final theme = PureTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: PureSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: theme.colors.primaryBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.tag, size: 18, color: theme.colors.primary),
              ),
              const SizedBox(width: PureSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.tag.startsWith('v') ? release.tag : 'v${release.tag}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.body.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (release.publishedAt != null)
                      Text(
                        context.t.about.publishedAt(date: _date(release)),
                        style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                      ),
                  ],
                ),
              ),
              PureIconButton(
                tooltip: context.t.about.openRelease,
                icon: Icons.open_in_new,
                onPressed: () => unawaited(_openRelease(release)),
              ),
            ],
          ),
          const SizedBox(height: PureSpacing.lg),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colors.fillSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colors.border.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [MarkdownText(release.body), ..._filesSection(context, release)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The changelog detail's download-files section: the release's published
  /// files (3.x `_VersionChangelogAndFilesWidget`'s tail), empty when the
  /// release publishes none.
  List<Widget> _filesSection(BuildContext context, AppRelease release) {
    if (release.assets.isEmpty) {
      return const <Widget>[];
    }
    return [
      const SizedBox(height: 20),
      Text(context.t.about.downloadFiles, style: PureTheme.of(context).text.body.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      for (final asset in release.assets)
        ReleaseFileCard(
          asset: asset,
          native: isNativeAsset(asset),
          onCopy: () => unawaited(_copyAssetLink(context, asset)),
          onDownload: () {
            final uri = asset.uri;
            if (uri != null) {
              unawaited(openReleaseUri(context, uri));
            }
          },
        ),
    ];
  }

  /// Copies an asset's download link (3.x `_copyDownloadLink`).
  Future<void> _copyAssetLink(BuildContext context, ReleaseAsset asset) async {
    final uri = asset.uri;
    if (uri == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (context.mounted) {
      PureToast.show(context, context.t.about.copied, type: PureToastType.success);
    }
  }

  /// The narrow layout's detail dialog (3.x `_showMobileDetailsDialog`).
  Future<void> _showDetails(BuildContext context, AppRelease release) {
    return showPureDialog<void>(
      context: context,
      title: release.tag.startsWith('v') ? release.tag : 'v${release.tag}',
      maxWidth: 560,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (release.publishedAt != null)
                Text(
                  context.t.about.publishedAt(date: _date(release)),
                  style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
                ),
              const SizedBox(height: PureSpacing.sm),
              MarkdownText(release.body),
              ..._filesSection(context, release),
            ],
          ),
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.about.openRelease,
          icon: Icons.open_in_new,
          variant: ButtonVariant.secondary,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            unawaited(_openRelease(release));
          },
        ),
        PureButton(
          label: dialogContext.t.common.close,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    );
  }
}

/// One published release file (3.x `_ReleaseFileCard`): the file's name over
/// its size and download count, with copy-link and download actions —
/// downloading hands the URL to the system browser, so it is the same
/// external-launch the release page uses.
final class ReleaseFileCard extends StatelessWidget {
  /// Shows [asset] with [onCopy] and [onDownload] as its actions; [native]
  /// marks the package built for this device (the reference's 本机 pill).
  const new({required this.asset, required this.onCopy, required this.onDownload, this.native = false, super.key});

  /// Whether this file runs on the current device.
  final bool native;

  /// The release file.
  final ReleaseAsset asset;

  /// Copies the file's download link.
  final VoidCallback onCopy;

  /// Downloads the file (opens it in the system browser).
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final hasLink = asset.uri != null;
    return Container(
      margin: const EdgeInsets.only(bottom: PureSpacing.sm),
      padding: const EdgeInsets.all(PureSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colors.fillSecondary.withValues(alpha: 0.35),
        border: Border.all(color: theme.colors.border.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: theme.colors.primaryBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.insert_drive_file_outlined, color: theme.colors.primary, size: 18),
          ),
          const SizedBox(width: PureSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (native) ...[
                      const SizedBox(width: PureSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: PureSpacing.xxs),
                        decoration: BoxDecoration(
                          color: theme.colors.primaryBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.t.about.native,
                          style: theme.text.caption.copyWith(
                            color: theme.colors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: PureSpacing.xxs),
                Text(
                  context.t.about.assetMeta(size: asset.sizeLabel, count: asset.downloads),
                  style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: PureSpacing.sm),
          PureIconButton(
            tooltip: context.t.about.copyLink,
            icon: Icons.copy_outlined,
            onPressed: hasLink ? onCopy : null,
          ),
          PureIconButton(
            tooltip: context.t.about.download,
            icon: Icons.download_outlined,
            onPressed: hasLink ? onDownload : null,
          ),
        ],
      ),
    );
  }
}

/// The release history as a page (the reference's `ReleaseHistoryView`):
/// the sheet's content under a scaffold, reachable from the about page and
/// the version page alike.
final class VersionHistoryPage extends ConsumerWidget {
  /// The history page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(versionControllerProvider.notifier);
    return PureScaffold(
      appBar: PureAppBar(title: context.t.about.versionHistory),
      body: VersionHistorySheet(
        releases: ref.watch(versionControllerProvider).releases,
        refresh: () async {
          await controller.check();
          return ref.read(versionControllerProvider).releases;
        },
      ),
    );
  }
}
