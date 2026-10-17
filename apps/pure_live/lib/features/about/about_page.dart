import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/about/markdown_text.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// About (3.x `AboutPage`): the app's identity, the update check against
/// the repository's published releases, the release notes, the project
/// page and the licenses.
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

  /// Fetches the releases; the first one answers the update check.
  Future<void> _check() async {
    if (_checking) {
      return;
    }
    setState(() {
      _checking = true;
      _feedError = null;
    });
    try {
      final releases = await ref.read(updateFeedProvider).fetch();
      if (!mounted) {
        return;
      }
      setState(() => _releases = releases);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _feedError = error);
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

  @override
  Widget build(BuildContext context) {
    final version = _info == null ? '…' : '${_info!.version}+${_info!.buildNumber}';
    final releases = _releases;
    final updateText = releases == null || releases.isEmpty
        ? (_feedError != null ? context.t.about.checkFailed : context.t.about.checkRunning)
        : (_hasUpdate(releases, version)
              ? '${context.t.about.newVersion} ${releases.first.tag}'
              : context.t.about.upToDate);
    return LiveScaffold(
      appBar: LiveAppBar(title: context.t.about.title, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          LiveCard(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Icon(Icons.live_tv, size: 56),
                const SizedBox(height: 8),
                Text(context.t.app.title, style: LiveTheme.of(context).text.headline),
                const SizedBox(height: 4),
                Text(version, style: LiveTheme.of(context).text.caption),
              ],
            ),
          ),
          LiveListRow(
            leading: const Icon(Icons.system_update_outlined),
            title: context.t.about.checkUpdate,
            subtitle: updateText,
            trailing: _checking ? const LiveSpinner(size: 20) : const Icon(Icons.chevron_right),
            onTap: _checking ? null : _check,
            divided: false,
          ),
          LiveListRow(
            leading: const Icon(Icons.history_outlined),
            title: context.t.about.versionHistory,
            trailing: const Icon(Icons.chevron_right),
            onTap: releases == null || releases.isEmpty ? null : () => _showHistory(context, releases),
            divided: false,
          ),
          LiveListRow(
            leading: const Icon(Icons.description_outlined),
            title: context.t.about.licenses,
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                showLicensePage(context: context, applicationName: context.t.app.title, applicationVersion: version),
            divided: false,
          ),
          LiveListRow(
            leading: const Icon(Icons.public_outlined),
            title: context.t.about.project,
            trailing: const Icon(Icons.open_in_new),
            onTap: () => unawaited(launchUrl(projectUrl, mode: LaunchMode.externalApplication)),
            divided: false,
          ),
          if (releases != null && releases.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 18), child: MarkdownText(releases.first.body)),
        ],
      ),
    );
  }

  Future<void> _showHistory(BuildContext context, List<AppRelease> releases) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(context.t.about.versionHistory, style: LiveTheme.of(context).text.title),
            const SizedBox(height: 12),
            for (final release in releases)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${release.tag}  ${release.name}', style: LiveTheme.of(context).text.title),
                    if (release.publishedAt != null)
                      Text(
                        release.publishedAt!.toLocal().toString().split(' ').first,
                        style: LiveTheme.of(context).text.caption,
                      ),
                    const SizedBox(height: 6),
                    MarkdownText(release.body),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
