import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/about/markdown_text.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/features/about/version_history.dart';
import 'package:pure_live/features/version/app_update_flow.dart';
import 'package:pure_live/features/version/version_controller.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The version page (3.x `VersionPage`): the running build, the check for
/// updates with its busy state, the newest release's notes and the release
/// history — routed at `/about/version`, where the reference routed its
/// update page.
///
/// Adapted to this app's graph: the state comes from
/// [versionControllerProvider] over the shared `updateFeedProvider` (no
/// GetX), the notes render through the app's own [MarkdownText], and the
/// update action opens the release's page (app_update_flow) — the app ships
/// no in-app installer, but the latest release's installable packages are
/// listed under the action, each handed to the system browser.
/// History is the one list [showVersionHistorySheet] already presents; this
/// page references it rather than growing a second one.
final class VersionPage extends ConsumerWidget {
  /// The version page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(versionControllerProvider);
    final controller = ref.read(versionControllerProvider.notifier);

    return PureScaffold(
      appBar: PureAppBar(title: context.t.about.versionUpdate, actions: const [SettingsEntryButton()]),
      body: state.releases.isEmpty && state.checking
          ? Center(child: PureLoading(message: context.t.common.loading))
          : state.releases.isEmpty && state.error != null
          ? PureError(
              message: context.t.about.checkFailed,
              onRetry: () => unawaited(controller.check()),
              retryLabel: context.t.common.retry,
            )
          : _page(context, ref, state),
    );
  }

  Widget _page(BuildContext context, WidgetRef ref, VersionState state) {
    final theme = PureTheme.of(context);
    final controller = ref.read(versionControllerProvider.notifier);
    final latest = state.releases.isEmpty ? null : state.releases.first;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _hero(context, theme, state),
        _groupTitle(context, context.t.about.group),
        PureCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              PureListRow(
                leading: const Icon(Icons.cloud_download_outlined),
                title: context.t.about.checkUpdate,
                subtitle: _verdict(context, state),
                trailing: state.checking
                    ? const PureSpinner()
                    : _versionPill(
                        theme,
                        latest != null && state.hasUpdate ? _tag(latest) : 'v${state.packageInfo?.version ?? '…'}',
                        highlight: state.hasUpdate,
                      ),
                onTap: state.checking ? null : () => unawaited(controller.check()),
              ),
              PureListRow(
                leading: const Icon(Icons.history),
                title: context.t.about.versionHistory,
                subtitle: context.t.about.historyDesc,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(const VersionHistoryRoute().push<void>(context)),
                divided: false,
              ),
            ],
          ),
        ),
        if (latest != null) ...[
          const SizedBox(height: 24),
          _groupTitle(context, context.t.about.updateLog),
          if (state.checking) const LinearProgressIndicator(minHeight: 2),
          PureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(_tag(latest), style: theme.text.body.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    if (state.hasUpdate)
                      PureButton(
                        label: context.t.about.update,
                        icon: Icons.open_in_new,
                        size: ControlSize.sm,
                        onPressed: () => unawaited(openReleasePage(context, latest)),
                      ),
                  ],
                ),
                ..._installableAssets(context, latest),
                const SizedBox(height: 8),
                MarkdownText(latest.body),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The check's verdict as the update row's subtitle.
  String _verdict(BuildContext context, VersionState state) {
    if (state.releases.isEmpty) {
      return state.error != null ? context.t.about.checkFailed : context.t.about.checkRunning;
    }
    return state.hasUpdate ? '${context.t.about.newVersion} ${_tag(state.releases.first)}' : context.t.about.upToDate;
  }

  /// The latest release's installable packages, listed under the update
  /// action (the page-level counterpart of the history sheet's download
  /// files): one row per package, downloading opens it in the browser.
  List<Widget> _installableAssets(BuildContext context, AppRelease latest) {
    final assets = latest.installableAssets;
    if (assets.isEmpty) {
      return const <Widget>[];
    }
    return [
      const SizedBox(height: 12),
      Text(
        context.t.about.downloadFiles,
        style: PureTheme.of(context).text.caption
            .copyWith(color: PureTheme.of(context).colors.textSecondary, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      for (final asset in assets)
        ReleaseFileCard(
          asset: asset,
          native: isNativeAsset(asset),
          onCopy: () async {
            final uri = asset.uri;
            if (uri == null) {
              return;
            }
            await Clipboard.setData(ClipboardData(text: uri.toString()));
            if (context.mounted) {
              PureToast.show(context, context.t.about.copied, type: PureToastType.success);
            }
          },
          onDownload: () {
            final uri = asset.uri;
            if (uri != null) {
              unawaited(openReleaseUri(context, uri));
            }
          },
        ),
    ];
  }

  /// The release's tag, v-prefixed.
  String _tag(AppRelease release) => release.tag.startsWith('v') ? release.tag : 'v${release.tag}';

  /// The identity block: the glyph tile (the app ships no icon asset), the
  /// app name and the running build's pill — the about page's hero, at rest.
  Widget _hero(BuildContext context, PureTheme theme, VersionState state) => Center(
    child: Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: theme.colors.primary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: theme.colors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Icon(Icons.live_tv_rounded, size: 42, color: theme.colors.primary),
        ),
        const SizedBox(height: 14),
        Text(context.t.app.title, style: theme.text.headline.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _versionPill(theme, 'v${state.packageInfo?.version ?? '…'}'),
        const SizedBox(height: 24),
      ],
    ),
  );

  /// The version pill: the rounded quiet chip, highlighted while an update
  /// is pending.
  Widget _versionPill(PureTheme theme, String text, {bool highlight = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: highlight ? theme.colors.primaryBg : theme.colors.fillSecondary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: theme.text.caption.copyWith(
        color: highlight ? theme.colors.primaryText : theme.colors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// The group header above a card.
  Widget _groupTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      title,
      style: PureTheme.of(context).text.caption
          .copyWith(color: PureTheme.of(context).colors.textSecondary, fontWeight: FontWeight.w600),
    ),
  );
}
