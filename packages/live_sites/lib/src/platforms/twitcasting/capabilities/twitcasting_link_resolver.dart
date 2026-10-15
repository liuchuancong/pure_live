import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TwitCasting's links: a channel page `twitcasting.tv/{id}` canonicalized
/// to the channel's own page without a request (3.x). Ids are lower case,
/// with their `c:`, `g:`, `f:` or `ig:` prefix. Movie and archive links name
/// one old broadcast and are not rooms (REG-TWITCASTING-003).
///
/// A link of another site is unsupported; a page of this site that names no
/// channel is not-found.
final class TwitcastingLinkResolver implements LiveLinkResolver {
  /// Serves [site].
  TwitcastingLinkResolver({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final channel = TwitcastingEndpoints.channelFromUri(uri);
    if (channel == null) {
      final ours = TwitcastingEndpoints.isSiteHost(uri.host.toLowerCase());
      return left(
        ours
            ? LiveSiteError.notFound(siteId: 'twitcasting', message: '"$uri" names no room')
            : LiveSiteError.unsupported(siteId: 'twitcasting', message: '"$uri" is not a TwitCasting link'),
      );
    }
    return right(Uri.parse(TwitcastingEndpoints.roomUrl(channel)));
  }
}
