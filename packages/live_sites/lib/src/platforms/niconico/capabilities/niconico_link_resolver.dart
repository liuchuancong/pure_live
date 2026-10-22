import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Resolves a niconico link to its canonical watch page
/// (`https://live.nicovideo.jp/watch/<room>`): a broadcaster's page
/// (`…/watch/user/<id>`, `…/watch/ch<n>`, `www.nicovideo.jp/user/<id>`,
/// `ch.nicovideo.jp/[channel/]ch<n>`) resolves to that broadcaster directly;
/// a program page (`…/watch/lv…`, `nico.ms/lv…`) reads its watch page once to
/// name the broadcaster behind the program, falling back to the program itself
/// when the page cannot be read.
final class NiconicoLinkResolver implements LiveLinkResolver {
  /// Resolves through [site] (its watch-page read).
  NiconicoLinkResolver({required this.site});

  /// The site whose watch page maps a program to its broadcaster.
  final NiconicoSite site;

  static const Set<String> _hosts = {
    'live.nicovideo.jp',
    'sp.live.nicovideo.jp',
    'nico.ms',
    'nicovideo.jp',
    'www.nicovideo.jp',
    'sp.nicovideo.jp',
    'ch.nicovideo.jp',
  };

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (!_hosts.contains(host)) {
      return left(LiveSiteError.unsupported(siteId: niconicoSiteId, message: 'not a niconico link: $uri'));
    }
    final text = '$uri';
    final broadcaster = NiconicoRoomParser.broadcasterRoomIdFromUrl(text);
    if (broadcaster != null) return right(NiconicoEndpoints.watchPage(broadcaster));
    final program = NiconicoRoomParser.programIdFromUrl(text);
    if (program == null) {
      return left(LiveSiteError.notFound(siteId: niconicoSiteId, message: 'no room in niconico link: $uri'));
    }
    try {
      final watch = await site.watch(program);
      return right(NiconicoEndpoints.watchPage(watch.room));
    } on NiconicoFailure {
      // The program's page could not be read: its own watch page is canonical.
      return right(NiconicoEndpoints.watchPage(program));
    }
  }
}
