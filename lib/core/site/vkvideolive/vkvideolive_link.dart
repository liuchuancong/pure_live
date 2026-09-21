final class VkVideoLiveChannelKey {
  const VkVideoLiveChannelKey(this.channel);

  final String channel;

  String get storageKey => channel.toLowerCase();
}

final class VkVideoLiveLink {
  const VkVideoLiveLink._();

  static const Set<String> _hosts = {'live.vkvideo.ru', 'live.vkplay.ru', 'vkplay.live', 'www.vkplay.live'};

  static const Set<String> _reserved = {'app', 'applications', 'clan', 'developers', 'login', 'record'};

  static VkVideoLiveChannelKey? parse(String raw) {
    final value = raw.trim();
    if (value.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !_hosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList(growable: false);
    if (segments.length != 1 || uri.hasQuery) return null;
    final channel = normalizeChannel(segments.single);
    if (channel == null || _reserved.contains(channel)) return null;
    return VkVideoLiveChannelKey(channel);
  }

  static VkVideoLiveChannelKey? parseKey(Object? raw) {
    if (raw is! String) return null;
    final parsed = parse(raw);
    if (parsed != null) return parsed;
    final channel = normalizeChannel(raw);
    return channel == null || _reserved.contains(channel) ? null : VkVideoLiveChannelKey(channel);
  }

  static String? normalizeChannel(Object? value) {
    if (value is! String) return null;
    final channel = value.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_.-]{1,64}$').hasMatch(channel) ? channel : null;
  }

  static String url(Object key) {
    final parsed = key is VkVideoLiveChannelKey ? key : parseKey(key);
    if (parsed == null) throw const FormatException('Invalid VK Video Live channel');
    return Uri.https('live.vkvideo.ru', '/${parsed.storageKey}').toString();
  }
}
