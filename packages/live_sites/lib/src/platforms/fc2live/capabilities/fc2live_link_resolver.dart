import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves an FC2 Live link to its canonical `https://live.fc2.com/<channel>/`.
///
/// FC2 has no short link to follow and no player-page embed to read: the channel
/// number stands in the page's own path, either bare or behind one of the site's
/// thirteen language prefixes, and it is the room. A host that is not
/// `live.fc2.com` is [LiveSiteUnsupported]; a page of that host that holds no
/// channel — `/rank/`, a channel's `/archive` — is [LiveSiteNotFound], because
/// there is nothing to resolve and following it would only fetch HTML.
final class Fc2LiveLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its identity and endpoint constants).
  Fc2LiveLinkResolver({required this.site});

  /// The site whose links this resolver recognizes.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    if (uri.host.toLowerCase() != Fc2LiveEndpoints.host) {
      return left(LiveSiteError.unsupported(siteId: 'fc2live', message: 'not an FC2 Live link: $uri'));
    }
    final id = Fc2LiveRoomParser.channelIdFromUrl('$uri');
    if (id == null) {
      return left(LiveSiteError.notFound(siteId: 'fc2live', message: 'no channel in FC2 Live link: $uri'));
    }
    return right(Uri.parse(Fc2LiveEndpoints.channelUrl(id)));
  }
}
