// Module: lib/src/identifiers/identity_key.dart
// Purpose: Build a string that names a thing, so two callers asking about the same object ask with the same
// text.
// Author: liuchuancong
// Created: 2026-10-10
//
// Two jobs, both about text used as a key rather than shown to a person.
//
// The first is composite cache keys: a resolver memoizes by (source, content, kind) and the storage layer
// namespaces by (domain, id). Joining with a separator looks fine until an id contains the separator, after
// which two different objects share one cache entry and the bug is a wrong picture in an unrelated room. A
// length prefix makes the concatenation injective, which a separator never can.
//
// The second is comparing identifiers that arrive from different places - an extension manifest against a
// scraped page - which is the cross-source dedup the identity package is waiting on. Case and padding are
// transport noise, not identity, so they are removed here rather than at each call site that happens to
// notice.

/// A key built from [parts], unambiguous about where each part ends.
///
/// `['a', 'bc']` and `['ab', 'c']` produce different keys; `['x']` and `[' x ']` also differ, because a
/// caller that wants folding should call [normalizeToken] on that part before passing it.
String identityKey(Iterable<Object?> parts) {
  final buffer = StringBuffer();
  for (final part in parts) {
    final text = '$part';
    // The length is written in decimal followed by a colon, which no part can fake: a part that itself
    // starts with digits and a colon still parses to the same boundary.
    buffer
      ..write(text.length)
      ..write(':')
      ..write(text);
  }
  return buffer.toString();
}

/// [raw] folded for comparison: trimmed, inner whitespace collapsed, lower-cased.
///
/// Only for ids and tokens, never for a title - folding a display string is how a user sees a name they did
/// not write.
String normalizeToken(String raw) {
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final code in trimmed.runes) {
    final isSpace = code == 0x20 || code == 0x09;
    if (isSpace) {
      pendingSpace = buffer.isNotEmpty;
      continue;
    }
    if (pendingSpace) {
      buffer.write(' ');
      pendingSpace = false;
    }
    buffer.writeCharCode(code);
  }
  return buffer.toString();
}

/// True when two tokens name the same thing after folding.
bool sameToken(String left, String right) => normalizeToken(left) == normalizeToken(right);
