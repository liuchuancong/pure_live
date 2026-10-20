import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/features/about/version_history.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// About (3.x `AboutPage`): the app's identity under a version pill, the
/// update check against the repository's published releases (3.x
/// `online_update`), the release history, the open-source licences, then the
/// project group with its homepage and its legal note.
///
/// The check runs once on open (the current app's own behaviour) and again
/// from the update row, whose verdict answers in place; the row itself
/// opens the version page, where the reference's update page lives
/// (3.x `RoutePath.kVersionPage`).
final class AboutPage extends ConsumerStatefulWidget {
  /// The about page.
  const new({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

final class _AboutPageState extends ConsumerState<AboutPage> {
  PackageInfo? _info;
  List<AppRelease>? _releases;
  Object? _feedError;
  bool _checking = false;
  bool _openingProject = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
    unawaited(_check());
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _info = info);
    }
  }

  /// Fetches the releases; the first one answers the update check. Returns
  /// them for callers that present the verdict; null on failure or re-entry.
  Future<List<AppRelease>?> _check() async {
    if (_checking) {
      return null;
    }
    setState(() {
      _checking = true;
      _feedError = null;
    });
    try {
      final releases = await ref.read(updateFeedProvider).fetch();
      if (!mounted) {
        return null;
      }
      setState(() => _releases = releases);
      return releases;
    } on Object catch (error) {
      if (!mounted) {
        return null;
      }
      setState(() => _feedError = error);
      return null;
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  /// Whether the newest release is newer than the running build.
  bool _hasUpdate(List<AppRelease> releases, String current) {
    if (releases.isEmpty) {
      return false;
    }
    try {
      final latest = Version.parse(releases.first.tag.replaceFirst(RegExp('^[vV]'), ''));
      final running = Version.parse(current);
      return latest > running;
    } on Object {
      return false;
    }
  }

  Future<void> _openProject() async {
    if (_openingProject) {
      return;
    }
    _openingProject = true;
    try {
      final opened = await launchUrl(projectUrl, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        PureToast.show(context, context.t.about.browserNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, context.t.about.browserNotOpened, type: PureToastType.error);
      }
    } finally {
      _openingProject = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final version = _info?.version;
    final releases = _releases;
    final updateText = releases == null || releases.isEmpty
        ? (_feedError != null ? context.t.about.checkFailed : context.t.about.checkRunning)
        : (_hasUpdate(releases, version ?? '')
              ? '${context.t.about.newVersion} ${releases.first.tag}'
              : context.t.about.upToDate);
    final hasUpdate = version != null && releases != null && _hasUpdate(releases, version);

    return PureScaffold(
      appBar: PureAppBar(title: context.t.about.title, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(PureSpacing.md),
        children: [
          _hero(context, theme, version),
          _groupTitle(context, context.t.about.group),
          PureCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PureListRow(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: context.t.about.onlineUpdate,
                  subtitle: updateText,
                  trailing: _checking
                      ? const PureSpinner()
                      : _versionPill(
                          theme,
                          hasUpdate && releases.first.tag.isNotEmpty ? releases.first.tag : 'v${version ?? '…'}',
                          highlight: hasUpdate,
                        ),
                  onTap: _checking ? null : () => unawaited(const VersionRoute().push(context)),
                ),
                PureListRow(
                  leading: const Icon(Icons.history),
                  title: context.t.about.versionHistory,
                  subtitle: context.t.about.historyDesc,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      unawaited(showVersionHistorySheet(context, ref, releases: releases ?? const [], refresh: _check)),
                ),
                PureListRow(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: context.t.about.licenses,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: context.t.app.title,
                    applicationLegalese: context.t.about.legalese,
                    applicationVersion: 'v${version ?? '…'}',
                    useRootNavigator: true,
                  ),
                  divided: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: PureSpacing.xl),
          _groupTitle(context, context.t.about.projectSection),
          PureCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _longRow(
                  context,
                  icon: Icons.code,
                  title: context.t.about.project,
                  subtitle: projectUrl.toString(),
                  onTap: () => unawaited(_openProject()),
                  trailing: Icon(Icons.open_in_new, size: 18, color: theme.colors.textSecondary),
                ),
                _longRow(
                  context,
                  icon: Icons.warning_amber_outlined,
                  iconColor: theme.colors.error,
                  title: context.t.about.projectAlert,
                  subtitle: context.t.about.legalese,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The identity block (3.x): the icon tile scaling in, the app name, the
  /// version pill. The app ships no icon asset, so the tile carries the
  /// app's glyph.
  Widget _hero(BuildContext context, PureTheme theme, String? version) => Center(
    child: Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colors.primary.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: theme.colors.primary.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(PureSpacing.lg),
            child: Icon(Icons.live_tv_rounded, size: 48, color: theme.colors.primary),
          ),
        ),
        const SizedBox(height: 18),
        Text(context.t.app.title, style: theme.text.headline.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        _versionPill(theme, 'v${version ?? '…'}'),
        const SizedBox(height: 28),
      ],
    ),
  );

  /// The version pill (3.x): the rounded quiet chip, highlighted while an
  /// update is pending.
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

  /// The group header above a card (3.x `buildGroupTitle`).
  Widget _groupTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(PureSpacing.xs, 0, PureSpacing.xs, PureSpacing.sm),
    child: Text(
      title,
      style: PureTheme.of(context).text.caption
          .copyWith(color: PureTheme.of(context).colors.textSecondary, fontWeight: FontWeight.w600),
    ),
  );

  /// A tile with a wrapping subtitle (3.x `buildTile(isLong:)`) — the
  /// [PureListRow] subtitle is a single line, and the project URL and the
  /// legal note both wrap.
  Widget _longRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = PureTheme.of(context);
    // PureBox, not a raw InkWell: cupertino, fluent and forui hosts have no
    // Material ancestor for the ink to paint on, and the tap would assert.
    return PureBox(
      style: (state) => Style(
        background: state == InteractionState.hovered ? theme.colors.fillQuaternary : null,
        borderRadius: BorderRadius.circular(theme.card.borderRadius),
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(PureSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: PureSpacing.xxs),
              child: Icon(icon, size: 22, color: iconColor ?? theme.colors.icon),
            ),
            const SizedBox(width: PureSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.text.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: PureSpacing.xxs),
                  Text(subtitle, style: theme.text.caption.copyWith(color: theme.colors.textSecondary, height: 1.5)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: PureSpacing.sm), trailing],
          ],
        ),
      ),
    );
  }
}
