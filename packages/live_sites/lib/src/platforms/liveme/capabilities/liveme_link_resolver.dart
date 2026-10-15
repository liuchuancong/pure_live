import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_link.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LiveMe's links: a room page canonicalized to itself without a request; an
/// anchor page (`/u/<uid>`) or a broadcast's share page (`/v/<vid>`,
/// `/m/v/<vid>/index.html`) resolved to its room page with one request (the
/// anchor's `getinfo`, or the broadcast's signed `queryinfosimple`).
///
/// A link of another site is unsupported; a page of this site that names no
/// room is not-found.
final class LivemeLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  LivemeLinkResolver({required this.site});

  /// The site this capability serves.
  final LivemeSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final link = LivemeLink.parse('$uri');
    if (link == null) {
      final host = uri.host.toLowerCase();
      final ours = host == 'liveme.com' || host == 'www.liveme.com' || host.endsWith('.liveme.com');
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'liveme', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'liveme', message: '"$uri" is not a LiveMe link'),
      );
    }
    final String shortId;
    switch (link.kind) {
      case LivemeLinkKind.shortId:
        shortId = link.id;
      case LivemeLinkKind.userId || LivemeLinkKind.videoId:
        try {
          shortId = await site.resolveLink(link);
        } on LivemeFailure catch (failure) {
          return left(failure.toLiveSiteError('liveme'));
        } on Object catch (error) {
          return left(LiveSiteError.unexpected(siteId: 'liveme', message: '$error', cause: error));
        }
    }
    return right(Uri.parse(LivemeEndpoints.roomUrl(shortId)));
  }
}
