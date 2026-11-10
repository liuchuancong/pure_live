import 'dart:async' show TimeoutException;

import 'package:live_iptv/live_iptv.dart' show IptvBytesFetcher, IptvFetcher;
import 'package:live_net/live_net.dart' show ConnectFailure, HttpStatusFailure, TimeoutFailure;
import 'package:pure_live/app/providers/network/github_mirror_provider.dart' show GithubMirrorState, kGithubRawOrigin;

/// The raw-file address of a GitHub page link, or null when [url] is not one.
///
/// Lists are shared as the page a browser shows (`github.com/o/r/blob/b/p`)
/// or its raw redirect (`github.com/o/r/raw/b/p`); the first is an HTML
/// page, not the list, and neither is an address a mirror knows how to
/// rewrite. Both become `raw.githubusercontent.com/o/r/b/p`, the one form
/// every accelerator speaks.
Uri? githubRawAddressOf(Uri url) {
  if (url.host == Uri.parse(kGithubRawOrigin).host) {
    return url;
  }
  if (url.host != 'github.com' && url.host != 'www.github.com') {
    return null;
  }
  final segments = url.pathSegments;
  // owner / repo / blob|raw / ref… / path…
  if (segments.length < 5 || (segments[2] != 'blob' && segments[2] != 'raw')) {
    return null;
  }
  return Uri.parse('$kGithubRawOrigin/${[segments[0], segments[1], ...segments.skip(3)].join('/')}');
}

/// The addresses a download of [url] tries, in order.
///
/// A GitHub list goes through the viewer's chosen accelerator first and the
/// raw origin after it — the mirror table is the app's one route to GitHub,
/// so an IPTV list never keeps a private one. A link the viewer typed stays
/// the last resort, unless it is a GitHub page, which answers with HTML.
List<Uri> iptvDownloadCandidates(Uri url, GithubMirrorState mirrors) {
  final raw = githubRawAddressOf(url);
  if (raw == null) {
    return [url];
  }
  final candidates = <Uri>[
    for (final address in mirrors.candidates(raw.toString()))
      if (Uri.tryParse(address) case final Uri parsed) parsed,
  ];
  final isPage = url.host != raw.host && url.pathSegments.length > 2 && url.pathSegments[2] == 'blob';
  if (!isPage && !candidates.contains(url)) {
    candidates.add(url);
  }
  return candidates;
}

/// [base] behind [iptvDownloadCandidates]: each address tried in turn, a
/// server hiccup (5xx, 429, a dropped connection) retried once on the same
/// address, and the last failure thrown when every address failed.
IptvFetcher routedIptvFetcher(IptvFetcher base, GithubMirrorState Function() mirrors) =>
    (url, {headers = const {}}) => _route(url, mirrors(), (candidate) => base(candidate, headers: headers));

/// The byte-fetching twin of [routedIptvFetcher].
IptvBytesFetcher routedIptvBytesFetcher(IptvBytesFetcher base, GithubMirrorState Function() mirrors) =>
    (url, {headers = const {}}) => _route(url, mirrors(), (candidate) => base(candidate, headers: headers));

Future<T> _route<T>(Uri url, GithubMirrorState mirrors, Future<T> Function(Uri candidate) download) async {
  Object? last;
  StackTrace? lastStack;
  for (final candidate in iptvDownloadCandidates(url, mirrors)) {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await download(candidate);
      } on Object catch (error, stack) {
        last = error;
        lastStack = stack;
        // A server that stumbled gets one more try; a timeout, a refusal or
        // a 404 moves on to the next address, which is what it is there for.
        if (attempt == 0 && _worthRetrying(error)) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          continue;
        }
        break;
      }
    }
  }
  Error.throwWithStackTrace(last ?? StateError('no address to download'), lastStack ?? StackTrace.current);
}

bool _worthRetrying(Object error) => switch (error) {
  HttpStatusFailure(:final statusCode) => statusCode >= 500 || statusCode == 429,
  ConnectFailure() => true,
  TimeoutFailure() || TimeoutException() => false,
  _ => false,
};
