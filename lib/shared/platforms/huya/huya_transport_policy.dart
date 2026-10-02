/// Shared classification of Huya credential and transport refresh policies.
abstract final class HuyaTransportPolicy {
  /// Renew a CDN by identity, never by its position in an old room snapshot.
  /// Keep the original list order for the selector and its lease metadata.
  static int selectRefreshedLine({
    required List<String> urls,
    required String? currentUrl,
    required int currentLineIndex,
    required bool advanceLine,
  }) {
    if (urls.isEmpty) return 0;
    final legacyIndex = currentLineIndex.clamp(0, urls.length - 1);
    final fallback = advanceLine ? (legacyIndex + 1) % urls.length : legacyIndex;
    final current = _mediaUri(currentUrl ?? '');
    if (current == null) return fallback;

    final candidates = urls.map(_mediaUri).toList(growable: false);
    final all = [
      for (var i = 0; i < candidates.length; i++)
        if (candidates[i] != null) i,
    ];
    final isFlv = current.path.toLowerCase().endsWith('.flv');
    final sameFormat = [
      for (final i in all)
        if (candidates[i]!.path.toLowerCase().endsWith('.flv') == isFlv) i,
    ];
    final wasNative = hasNativeFlvCredential(currentUrl!);
    final native = [
      for (final i in sameFormat)
        if (hasNativeFlvCredential(urls[i])) i,
    ];

    for (final pool in [if (wasNative) native, sameFormat, all]) {
      if (pool.isEmpty) continue;
      bool sameCdn(int i) =>
          candidates[i]!.host == current.host &&
          candidates[i]!.port == current.port &&
          hasNativeFlvCredential(urls[i]) == wasNative;
      var position = pool.indexWhere((i) => sameCdn(i) && candidates[i]!.path == current.path);
      // Stream names can rotate when the broadcaster restarts. The CDN and
      // format still identify the viewer's line in the refreshed room snapshot.
      if (position < 0) position = pool.indexWhere(sameCdn);
      if (position < 0) return pool.first;
      if (!advanceLine) return pool[position];
      if (pool.length > 1) return pool[(position + 1) % pool.length];
      // The only native line failed: broaden to web FLV, then HLS rather than
      // retrying that same endpoint forever or deleting the fallback choices.
    }
    return fallback;
  }

  static Uri? _mediaUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    if (uri.host != 'huya.com' && !uri.host.endsWith('.huya.com')) return null;
    final path = uri.path.toLowerCase();
    return path.endsWith('.flv') || path.endsWith('.m3u8') ? uri : null;
  }

  static bool hasShortTransportLease(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    final isHuya = host == 'huya.com' || host.endsWith('.huya.com');
    if (!isHuya || (!path.endsWith('.flv') && !path.endsWith('.m3u8'))) return false;
    // The native WUP FLV connection outlives its credential in long-read probes.
    // Refresh the next credential without restarting a healthy current stream.
    return !hasNativeFlvCredential(url);
  }

  static bool hasNativeFlvCredential(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    if (host != 'huya.com' && !host.endsWith('.huya.com')) return false;
    return (uri?.path.toLowerCase().endsWith('.flv') ?? false) &&
        uri!.queryParameters['ctype'] == 'huya_pc_exe' &&
        uri.queryParameters['t'] == '100';
  }
}
