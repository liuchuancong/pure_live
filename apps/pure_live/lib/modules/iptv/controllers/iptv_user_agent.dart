import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The reference's `customIptvUserAgent`: one User-Agent for IPTV downloads
/// and playback requests. Empty uses the app's normal client identity.
const String kIptvUserAgentKey = 'iptv.userAgent';

/// Owns that override. Persists under [kIptvUserAgentKey]; an empty value
/// removes the key so a fresh install and a cleared field are the same.
final class IptvUserAgentController extends Notifier<String> {
  @override
  String build() {
    try {
      return StoragePrefs.getString(kIptvUserAgentKey)?.trim() ?? '';
    } on Object {
      return '';
    }
  }

  /// Stores [value] trimmed; whitespace alone clears the override.
  Future<void> set(String value) async {
    final next = value.trim();
    state = next;
    try {
      if (next.isEmpty) {
        await StoragePrefs.remove(kIptvUserAgentKey);
      } else {
        await StoragePrefs.setString(kIptvUserAgentKey, next);
      }
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The custom IPTV User-Agent, or empty when the app default is used.
final iptvUserAgentProvider = NotifierProvider<IptvUserAgentController, String>(IptvUserAgentController.new);

/// The header value to send, or null when the viewer left the field empty.
String? normalizedIptvUserAgent(String value) {
  final agent = value.trim();
  return agent.isEmpty ? null : agent;
}

/// Adds the custom User-Agent to [headers] unless the entry already carries
/// one (the playlist line's own header wins, as in the reference).
Map<String, String> iptvHeadersWithUserAgent(Map<String, String> headers, String userAgent) {
  final agent = normalizedIptvUserAgent(userAgent);
  if (agent == null) return headers;
  if (headers.keys.any((key) => key.toLowerCase() == 'user-agent')) return headers;
  return {...headers, 'user-agent': agent};
}
