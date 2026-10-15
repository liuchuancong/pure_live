import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a SOOP link to its canonical room page
/// `https://play.sooplive.co.kr/<id>`, without a request: the streamer id is
/// written in the page's own path, on the live hosts or on the former
/// `afreecatv.com`, as the first segment or the one after `station`.
///
/// A host that is not SOOP's is unsupported (the resolver hands the caller
/// an unsupported link, never a guess); a page of a SOOP host that is no
/// streamer page is not-found.
final class SoopLinkResolver implements LiveLinkResolver {
  /// Serves [site] (its endpoint constants and identity).
  SoopLinkResolver({required this.site});

  /// The site whose links this resolver recognizes.
  final SoopSite site;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final canonical = site.canonicalRoomUrl(uri);
    if (canonical != null) return right(canonical);
    return left(
      SoopSite.ownsHost(uri)
          ? LiveSiteError.notFound(siteId: 'soop', message: '"$uri" names no room')
          : LiveSiteError.unsupported(siteId: 'soop', message: '"$uri" is not a SOOP link'),
    );
  }
}
