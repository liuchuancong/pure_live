import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_cache/src/image/image_cache_policy.dart';
import 'package:meta/meta.dart';

/// One image the cache is asked for.
///
/// The request carries the business identity, never the resolved file path:
/// storage derives that from [diskKey].
@immutable
final class ImageCacheRequest {
  /// Creates a request for [url] under [policy].
  ///
  /// An explicit [cacheKey] wins over the URL as the identity — the caller
  /// uses it when the server rotates signed query strings. [version] folds a
  /// business version in on top of the policy's own. [accountScope] keeps two
  /// accounts' private images apart even when the URL matches.
  const new({
    required this.url,
    required this.policy,
    this.cacheKey,
    this.version,
    this.accountScope,
    this.headers = const {},
  });

  /// A request whose identity is a business key rather than a URL, for bytes
  /// the caller already holds (a converted cover, say).
  factory business({
    required String key,
    required ImageCachePolicy policy,
    String? version,
    String? accountScope,
    Map<String, String> headers = const {},
  }) => ImageCacheRequest(
    url: Uri(),
    policy: policy,
    cacheKey: key,
    version: version,
    accountScope: accountScope,
    headers: headers,
  );

  /// The absolute image URL.
  final Uri url;

  /// The category rules that apply.
  final ImageCachePolicy policy;

  /// An explicit stable identity, when the URL is not one.
  final String? cacheKey;

  /// A business version; changing it makes a new file.
  final String? version;

  /// A safe account identifier when two sessions could share a URL with
  /// different private content.
  final String? accountScope;

  /// Extra request headers, e.g. a referer some hosts require.
  final Map<String, String> headers;

  /// The un-hashed identity: the explicit key, or the URL.
  String get identity => cacheKey ?? url.toString();

  /// The version folded into the key.
  String? get effectiveVersion => version ?? policy.version;

  /// The SHA-256 file stem: category, identity, version and account scope.
  ///
  /// URLs and tokens never become file names or log fields.
  String get diskKey {
    final material = [policy.category, identity, effectiveVersion ?? '', accountScope ?? ''].join('\u0000');
    return sha256.convert(utf8.encode(material)).toString();
  }

  /// The folder-safe category segment.
  String get categorySlug {
    final lowered = policy.category.toLowerCase();
    final slug = lowered.replaceAll(RegExp('[^a-z0-9_-]'), '_');
    return slug.isEmpty ? 'general' : slug;
  }
}
