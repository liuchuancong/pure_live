import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/about/about_routes.dart';
import 'package:pure_live/features/about/markdown_text.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/features/home/home_menu.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// The home domain's shell page: the section menu the user opens the app's
/// destinations from (3.x `HomeMenu`; the destinations open as full pages
/// above the shell, exactly as the routes plan them).
///
/// It also carries the reference home's one start-up behaviour that this
/// architecture can host: a delayed update check against the repository's
/// published releases, prompting with the new version's notes when the feed
/// is ahead of the running build (3.x `HomePage` + `NewVersionDialog`). The
/// check waits behind the first frames — the reference gives the visible
/// page the cold start's network before this low-priority work — and stays
/// silent on any failure; the About page offers the manual check.
///
/// The menu shows what exists — a destination appears with its feature
/// wave, never as a placeholder.
final class HomePage extends ConsumerStatefulWidget {
  /// The home page.
  const new({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends ConsumerState<HomePage> {
  /// The reference's delay: the visible page takes the cold start's network
  /// and build isolate first; the update check is background work.
  static const Duration _updateCheckDelay = Duration(seconds: 2);

  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCheckTimer = Timer(_updateCheckDelay, _checkForStartupUpdate);
    });
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  /// The reference's start-up check: read the running build, read the feed's
  /// newest release, prompt when the release is newer. Every failure is
  /// swallowed — a start-up check must never surface an error dialog.
  Future<void> _checkForStartupUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final releases = await ref.read(updateFeedProvider).fetch(limit: 1);
      if (!mounted || releases.isEmpty || !releases.first.hasVersion) {
        return;
      }
      if (!_isReleaseNewer(releases.first.tag, info.version)) {
        return;
      }
      final release = releases.first;
      if (!mounted) {
        return;
      }
      await showPureDialog<void>(
        context: context,
        title: context.t.about.checkUpdate,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PureListRow(
              leading: const Icon(Icons.open_in_new),
              title: context.t.about.openSourceFree,
              onTap: () => unawaited(launchUrl(projectUrl, mode: LaunchMode.externalApplication)),
              divided: false,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: MarkdownText(release.body),
            ),
          ],
        ),
        actions: (dialogContext) => [
          PureButton(
            label: dialogContext.t.common.cancel,
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          PureButton(
            label: dialogContext.t.about.update,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(const AboutRoute().push<void>(context));
            },
          ),
        ],
      );
    } on Object {
      // Best-effort, exactly as the reference's: skip silently.
    }
  }

  /// Whether [tag] names a version newer than the running [build].
  bool _isReleaseNewer(String tag, String build) {
    try {
      final latest = Version.parse(tag.replaceFirst(RegExp('^[vV]'), ''));
      final running = Version.parse(build);
      return latest > running;
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => PureScaffold(
    appBar: PureAppBar(title: context.t.tabs.home, actions: const [SettingsEntryButton()]),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in HomeMenuEntry.all(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PureCard(
              padding: EdgeInsets.zero,
              child: PureListRow(
                leading: Icon(entry.icon),
                title: entry.label,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => entry.onOpen(context),
                divided: false,
              ),
            ),
          ),
      ],
    ),
  );
}
