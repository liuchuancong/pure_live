import 'package:flutter/material.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:url_launcher/url_launcher.dart';

/// The update action's flow (3.x `app_update_flow`), reduced to what this
/// app can honestly do: it ships no download-and-install pipeline, so the
/// update action hands the user to the release's page — the place updates
/// actually come from — the same door the about page's verdict dialogs use.
///
/// The reference's mirror list, APK permission dance and download directory
/// prompt all serve the in-app installer this app does not have and are left
/// there.

/// The release's page: the feed's own link when it has one, the project's
/// release list otherwise.
Uri releasePageUri(AppRelease release) {
  final htmlUrl = release.htmlUrl.trim();
  if (htmlUrl.isNotEmpty) {
    return Uri.parse(htmlUrl);
  }
  final tag = release.tag.trim();
  return Uri.parse(tag.isEmpty ? '$projectUrl/releases' : '$projectUrl/releases/tag/$tag');
}

/// Opens [release]'s page in the system browser. A browser that does not
/// open toasts instead of throwing — the update action must never die on a
/// missing external handler.
Future<void> openReleasePage(BuildContext context, AppRelease release) =>
    openReleaseUri(context, releasePageUri(release));

/// Opens [uri] in the system browser, with the same never-die toast as
/// [openReleasePage] — the download-file actions hand release assets here.
Future<void> openReleaseUri(BuildContext context, Uri uri) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      PureToast.show(context, context.t.about.browserNotOpened, type: PureToastType.error);
    }
  } on Object {
    if (context.mounted) {
      PureToast.show(context, context.t.about.browserNotOpened, type: PureToastType.error);
    }
  }
}
