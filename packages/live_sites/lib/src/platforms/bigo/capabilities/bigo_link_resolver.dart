import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a Bigo link to its canonical `https://www.bigo.tv/{id}` page.
///
/// Bigo has no short link to follow: the id is written in the page's own path,
/// on `bigo.tv` or any of its subdomains, alone or behind a two-letter language.
/// A host that is not Bigo's is [LiveSiteUnsupported] (the resolver hands the
/// caller an unsupported link, never a guess); a Bigo page that is not a room
/// (one of the site's own pages, or a path with no id in it) is
/// [LiveSiteNotFound]. The id keeps the site's spelling — a room read answers
/// with the studio's own `clientBigoId`.
final class BigoLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its endpoint constants and identity).
  BigoLinkResolver({required this.site});

  /// The site whose links this resolver recognizes.
  final BigoSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != 'bigo.tv' && !host.endsWith('.bigo.tv')) {
      return left(LiveSiteError.unsupported(siteId: bigoSiteId, message: 'not a bigo link: $uri'));
    }
    final id = BigoRoomParser.siteIdFromUrl('$uri');
    if (id == null) {
      return left(LiveSiteError.notFound(siteId: bigoSiteId, message: 'no room in bigo link: $uri'));
    }
    return right(Uri.parse(BigoRoomParser.link(id)));
  }
}
