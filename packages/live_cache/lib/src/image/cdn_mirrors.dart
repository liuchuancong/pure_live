/// Interchangeable CDN node families, for the mirror fallback.
///
/// Some image CDNs serve one asset from several interchangeable node
/// pools: the path and its query (a signature included) are honoured by
/// every node of the family, so a connection that dies on one node can be
/// replayed on another without re-signing. The table names those node
/// pools; the loader consults it only when the original node's transport
/// broke (a timeout, a refused or dropped connection, a handshake cut
/// mid-flight) — an HTTP status is the same answer on every node and is
/// never retried across the family.
library;

/// The known families, keyed by the domain suffix every member shares.
const Map<String, List<String>> _cdnMirrorFamilies = <String, List<String>>{
  // Douyin's picture CDN: the plain, webcast and signed-webcast node
  // pools answer for one another's assets. Measured in the wild: a client
  // behind a flaky route loses whole pools at a time (the OS answers
  // errno 121, or the handshake dies mid-flight), while a sibling pool
  // answers immediately.
  'douyinpic.com': <String>[
    'p3.douyinpic.com',
    'p6.douyinpic.com',
    'p9.douyinpic.com',
    'p26.douyinpic.com',
    'p3-webcast.douyinpic.com',
    'p9-webcast.douyinpic.com',
    'p11-webcast.douyinpic.com',
    'p3-webcast-sign.douyinpic.com',
    'p9-webcast-sign.douyinpic.com',
    'p11-webcast-sign.douyinpic.com',
  ],
};

/// The same asset served by the other nodes of [url]'s CDN family.
///
/// Answers an empty list for a host outside every known family, so the
/// loader falls straight through with no mirror to try.
List<Uri> mirrorsFor(Uri url) {
  final host = url.host.toLowerCase();
  for (final entry in _cdnMirrorFamilies.entries) {
    if (!host.endsWith('.${entry.key}') && host != entry.key) {
      continue;
    }
    final mirrors = <Uri>[];
    for (final mirror in entry.value) {
      if (mirror == host) {
        continue;
      }
      mirrors.add(url.replace(host: mirror));
    }
    return mirrors;
  }
  return const <Uri>[];
}
