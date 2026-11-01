import 'package:crypto/crypto.dart' as crypto show sha256;

/// Public-key fingerprints and their comparisons.
///
/// Fingerprints are `sha256:`-prefixed hex digests of the peer's public key
/// material (spec §9.3). A presented fingerprint that differs from the
/// paired one is an identity mismatch — never an update (spec §8.4, §20).
abstract final class KeyFingerprints {
  /// Computes `sha256:<hex>` over [material].
  static String sha256(List<int> material) => 'sha256:${crypto.sha256.convert(material)}';

  /// Normalizes a fingerprint: trims, lowercases, accepts with or without
  /// the `sha256:` prefix. Returns null for anything that is not 32 bytes
  /// of hex.
  static String? normalize(String presented) {
    var value = presented.trim().toLowerCase();
    if (value.startsWith('sha256:')) {
      value = value.substring('sha256:'.length);
    }
    if (value.length != 64) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) return null;
    return 'sha256:$value';
  }

  /// Whether [presented] and [stored] name the same key. Both sides are
  /// normalized; anything unparseable never matches.
  static bool matches(String presented, String stored) {
    final left = normalize(presented);
    final right = normalize(stored);
    return left != null && right != null && left == right;
  }

  /// Compares two already-normalized fingerprints in time independent of
  /// where the first difference is.
  static bool secureEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
