import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:pure_live/features/about/markdown_text.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// The update-check dialogs (3.x `NoNewVersionDialog` / `NewVersionDialog`):
/// the check's verdict as a modal — the running build is current, or the
/// newest release's notes with the project links.
///
/// The reference's dialog ends in an in-app update page; the app has no
/// download-and-install flow, so both actions open the project's release
/// page — the place updates actually come from — and the notes stay the
/// dialog's body either way.

/// The up-to-date verdict (3.x `NoNewVersionDialog`).
Future<void> showNoUpdateDialog(BuildContext context) => showPureDialog<void>(
  context: context,
  title: context.t.about.checkUpdate,
  child: Text(context.t.about.noNewVersion),
  actions: (dialogContext) => [
    PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop()),
  ],
);

/// The new-version verdict (3.x `NewVersionDialog`): the [release]'s notes
/// under the open-project button, with the release page as the primary
/// action.
Future<void> showNewVersionDialog(BuildContext context, {required AppRelease release}) {
  return showPureDialog<void>(
    context: context,
    title: context.t.about.checkUpdate,
    maxWidth: 480,
    child: Builder(
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PureButton(
            label: dialogContext.t.about.openSourceFree,
            icon: Icons.open_in_new_rounded,
            variant: ButtonVariant.ghost,
            size: ControlSize.sm,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(launchUrl(projectUrl, mode: LaunchMode.externalApplication));
            },
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(child: MarkdownText(release.body)),
          ),
          const SizedBox(height: 10),
        ],
      ),
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
          final tag = release.tag.trim();
          final uri = tag.isEmpty ? Uri.parse('$projectUrl/releases') : Uri.parse('$projectUrl/releases/tag/$tag');
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        },
      ),
    ],
  );
}
