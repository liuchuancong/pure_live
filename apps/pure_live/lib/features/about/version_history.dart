import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:pure_live/features/about/markdown_text.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// The version-history presentation (3.x `VersionHistoryPage`): the release
/// list beside its changelog detail, refreshed from the update feed.
///
/// The reference presents this as a routed page — wide screens get a
/// two-pane layout, narrow ones a list whose rows open a detail dialog. The
/// app's routes own no history page, so the same presentation runs as a
/// sheet: two panes when the sheet is wide, list + dialog when narrow.
///
/// The reference's download-files section needs per-release asset metadata,
/// which the app's feed does not carry, so it has nothing to show and is
/// left out.

/// Opens the history as a sheet over [context].
Future<void> showVersionHistorySheet(
  BuildContext context, {
  required List<AppRelease> releases,
  required Future<List<AppRelease>?> Function() refresh,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 860),
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.75,
        child: VersionHistorySheet(releases: releases, refresh: refresh),
      ),
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

  /// The release's page; the feed's own link when it has one, the project's
  /// release tag otherwise.
  Uri _releaseUrl(AppRelease release) {
    final htmlUrl = release.htmlUrl.trim();
    if (htmlUrl.isNotEmpty) {
      return Uri.parse(htmlUrl);
    }
    final tag = release.tag.trim();
    return Uri.parse(tag.isEmpty ? '$projectUrl/releases' : '$projectUrl/releases/tag/$tag');
  }

  Future<void> _openRelease(AppRelease release) async {
    try {
      final opened = await launchUrl(_releaseUrl(release), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        PureToast.show(context, context.t.about.browserNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, context.t.about.browserNotOpened, type: PureToastType.error);
      }
    }
  }

  String _date(AppRelease release) => release.publishedAt?.toLocal().toString().split(' ').first ?? '—';

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
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
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _releases.isEmpty
                ? PureEmpty(title: context.t.common.empty)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 700;
                      final list = _list(context, wide: wide);
                      if (!wide) {
                        return list;
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 300, child: list),
                          const SizedBox(width: 16),
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
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: _releases.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final release = _releases[index];
        final current = index == _selected;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
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
                      const SizedBox(height: 2),
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
      padding: const EdgeInsets.only(top: 4),
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
              const SizedBox(width: 12),
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
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colors.fillSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colors.border.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(child: MarkdownText(release.body)),
            ),
          ),
        ],
      ),
    );
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
              const SizedBox(height: 8),
              MarkdownText(release.body),
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
