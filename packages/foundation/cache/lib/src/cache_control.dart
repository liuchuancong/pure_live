// Module: lib/src/cache_control.dart
// Purpose: Read an HTTP cache-control answer and decide what a cache is allowed to do with it.
// Author: liuchuancong
// Created: 2026-10-11
//
// The decision is here rather than in the network package because it is a cache policy, not a transport
// concern, and both are L0 - which means neither may import the other. The transport hands over the header
// text and the clock facts; this file answers "may I serve this from cache, and for how long".

/// The cache directives one response carried, already parsed.
///
/// Only the directives that change a decision are kept. Unknown directives are dropped rather than rejected:
/// a registry that failed on a directive it had not seen would turn every new CDN feature into a cache miss.
final class CacheControl {
  const CacheControl({
    this.maxAge,
    this.sharedMaxAge,
    this.staleWhileRevalidate,
    this.staleIfError,
    this.noStore = false,
    this.noCache = false,
    this.mustRevalidate = false,
    this.proxyRevalidate = false,
    this.isPublic = false,
    this.isPrivate = false,
    this.immutable = false,
    this.onlyIfCached = false,
  });

  /// Nothing was said about caching, which is not the same as "do not cache".
  static const CacheControl absent = CacheControl();

  /// Lifetime in seconds from the response's own date, or null when the response set none.
  final Duration? maxAge;

  /// The shared-cache lifetime (`s-maxage`), which wins over [maxAge] for a cache several users share.
  final Duration? sharedMaxAge;

  /// How long past freshness a stale copy may still be served while a revalidation runs in the background.
  final Duration? staleWhileRevalidate;

  /// How long past freshness a stale copy may be served when revalidation itself fails.
  final Duration? staleIfError;

  final bool noStore;
  final bool noCache;
  final bool mustRevalidate;
  final bool proxyRevalidate;
  final bool isPublic;
  final bool isPrivate;

  /// The resource never changes at this url, so an expired entry is still correct.
  final bool immutable;

  /// The client asked for a cached answer only, and a miss must not reach the network.
  final bool onlyIfCached;

  /// Parses one `cache-control` header value.
  ///
  /// Case-insensitive on names, tolerant of whitespace and of a missing value (`immutable` carries none).
  /// A malformed number is read as "not present" instead of poisoning the whole header, because a single bad
  /// directive from one CDN should not disable caching for every response behind it.
  factory CacheControl.parse(String? header) {
    if (header == null || header.trim().isEmpty) {
      return absent;
    }
    Duration? maxAge;
    Duration? sharedMaxAge;
    Duration? staleWhileRevalidate;
    Duration? staleIfError;
    var noStore = false, noCache = false, mustRevalidate = false, proxyRevalidate = false;
    var isPublic = false, isPrivate = false, immutable = false, onlyIfCached = false;

    for (final raw in header.split(',')) {
      final directive = raw.trim();
      if (directive.isEmpty) {
        continue;
      }
      final equals = directive.indexOf('=');
      final name = (equals < 0 ? directive : directive.substring(0, equals)).trim().toLowerCase();
      var value = equals < 0 ? '' : directive.substring(equals + 1).trim();
      if (value.length > 1 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      final seconds = int.tryParse(value);
      switch (name) {
        case 'max-age':
          maxAge = seconds == null ? null : Duration(seconds: seconds);
        case 's-maxage':
          sharedMaxAge = seconds == null ? null : Duration(seconds: seconds);
        case 'stale-while-revalidate':
          staleWhileRevalidate = seconds == null ? null : Duration(seconds: seconds);
        case 'stale-if-error':
          staleIfError = seconds == null ? null : Duration(seconds: seconds);
        case 'no-store':
          noStore = true;
        case 'no-cache':
          noCache = true;
        case 'must-revalidate':
          mustRevalidate = true;
        case 'proxy-revalidate':
          proxyRevalidate = true;
        case 'public':
          isPublic = true;
        case 'private':
          isPrivate = true;
        case 'immutable':
          immutable = true;
        case 'only-if-cached':
          onlyIfCached = true;
      }
    }
    return CacheControl(
      maxAge: maxAge,
      sharedMaxAge: sharedMaxAge,
      staleWhileRevalidate: staleWhileRevalidate,
      staleIfError: staleIfError,
      noStore: noStore,
      noCache: noCache,
      mustRevalidate: mustRevalidate,
      proxyRevalidate: proxyRevalidate,
      isPublic: isPublic,
      isPrivate: isPrivate,
      immutable: immutable,
      onlyIfCached: onlyIfCached,
    );
  }

  /// Parses the comma-joined `set-cookie`-style multi-header form some stacks produce.
  static CacheControl parseAll(Iterable<String?> headers) {
    final joined = headers.whereType<String>().where((h) => h.trim().isNotEmpty).join(', ');
    return joined.isEmpty ? absent : CacheControl.parse(joined);
  }

  /// The lifetime this cache should apply, given whether it is shared between users.
  ///
  /// A shared cache obeys `s-maxage` and must treat `private` as "not for me"; a private cache obeys
  /// `max-age` and may keep a `private` response.
  Duration? lifetimeFor({required bool isShared}) {
    if (noStore) {
      return null;
    }
    if (isShared) {
      if (isPrivate) {
        return null;
      }
      return sharedMaxAge ?? maxAge;
    }
    return maxAge;
  }

  @override
  String toString() {
    final parts = <String>[
      if (noStore) 'no-store',
      if (noCache) 'no-cache',
      if (maxAge != null) 'max-age=${maxAge!.inSeconds}',
      if (sharedMaxAge != null) 's-maxage=${sharedMaxAge!.inSeconds}',
      if (staleWhileRevalidate != null) 'stale-while-revalidate=${staleWhileRevalidate!.inSeconds}',
      if (immutable) 'immutable',
      if (mustRevalidate) 'must-revalidate',
      if (isPrivate) 'private',
      if (isPublic) 'public',
    ];
    return 'CacheControl(${parts.join(', ')})';
  }
}

/// What a cache may do with one stored response right now.
enum CacheVerdict {
  /// Fresh: serve it and do not touch the network.
  fresh,

  /// Stale but inside `stale-while-revalidate`: serve it now and refresh behind the caller.
  staleUsable,

  /// Stale and only usable if the revalidation itself fails (`stale-if-error`).
  staleForErrorOnly,

  /// Must ask the origin, with a conditional request when a validator is held.
  revalidate,

  /// Must not be served at all.
  unusable,
}

/// One decision about a stored response.
final class CacheDecision {
  const CacheDecision({required this.verdict, required this.age, this.freshFor, this.reason = ''});

  final CacheVerdict verdict;

  /// How long the entry has been stored, in the clock the caller supplied.
  final Duration age;

  /// How much longer it would stay fresh, or null when it is not fresh.
  final Duration? freshFor;

  /// Why, in words a diagnostics view can show. Empty for the obvious case.
  final String reason;

  bool get mayServeWithoutNetwork => verdict == CacheVerdict.fresh;
  bool get mayServeStale => verdict == CacheVerdict.fresh || verdict == CacheVerdict.staleUsable;

  @override
  String toString() => 'CacheDecision(${verdict.name}, age ${age.inSeconds}s${reason.isEmpty ? '' : ', $reason'})';
}

/// The facts a decision needs about one stored entry.
final class StoredResponseFacts {
  const StoredResponseFacts({
    required this.storedAt,
    required this.control,
    this.dateHeader,
    this.expiresHeader,
    this.etag,
    this.lastModified,
    this.isSharedCache = false,
  });

  /// When this cache wrote the entry.
  final DateTime storedAt;

  final CacheControl control;

  /// The origin's own `Date`, which is what age is measured against: a response that sat in a CDN for an hour
  /// is an hour older than the moment this cache saw it.
  final DateTime? dateHeader;

  /// The absolute `Expires` value, used only when no `max-age` was given.
  final DateTime? expiresHeader;

  final String? etag;
  final DateTime? lastModified;

  /// Whether this cache is shared between users, which changes which directives apply.
  final bool isSharedCache;

  bool get hasValidator => (etag != null && etag!.isNotEmpty) || lastModified != null;
}

/// Decides what may be served, from the entry's own facts and the current time.
///
/// [now] is a parameter rather than a clock read so one call site cannot disagree with the timestamp it stored
/// the entry under - the pair is what makes an age meaningful.
CacheDecision decideCacheUse(StoredResponseFacts facts, {required DateTime now, Duration? defaultLifetime}) {
  final at = now.toUtc();
  final origin = (facts.dateHeader ?? facts.storedAt).toUtc();
  final age = at.difference(origin);
  if (age.isNegative) {
    // A clock that moved backwards, or an origin in the future. Treat as zero rather than as infinitely fresh:
    // a negative age would make every entry immortal.
    return _decide(facts, Duration.zero, at, defaultLifetime);
  }
  return _decide(facts, age, at, defaultLifetime);
}

CacheDecision _decide(StoredResponseFacts facts, Duration age, DateTime at, Duration? defaultLifetime) {
  final control = facts.control;
  if (control.noStore) {
    return CacheDecision(verdict: CacheVerdict.unusable, age: age, reason: 'the response said no-store');
  }

  final lifetime = control.lifetimeFor(isShared: facts.isSharedCache) ?? _fromExpires(facts, at) ?? defaultLifetime;
  if (lifetime == null) {
    // Nothing states a lifetime. `no-cache` and `immutable` are the two directives that still decide
    // something; otherwise a heuristic default is the caller's business, not this file's.
    if (control.immutable) {
      return CacheDecision(verdict: CacheVerdict.fresh, age: age, reason: 'immutable');
    }
    if (control.noCache || control.mustRevalidate) {
      return CacheDecision(
        verdict: CacheVerdict.revalidate,
        age: age,
        reason: control.noCache ? 'no-cache requires revalidation' : 'must-revalidate',
      );
    }
    return CacheDecision(verdict: CacheVerdict.revalidate, age: age, reason: 'no lifetime stated');
  }

  if (control.immutable) {
    return CacheDecision(verdict: CacheVerdict.fresh, age: age, freshFor: lifetime, reason: 'immutable');
  }
  if (age <= lifetime) {
    if (control.noCache) {
      // Fresh by clock but the origin asked to be revalidated every time.
      return CacheDecision(
        verdict: CacheVerdict.revalidate,
        age: age,
        freshFor: lifetime - age,
        reason: 'no-cache overrides the clock',
      );
    }
    return CacheDecision(verdict: CacheVerdict.fresh, age: age, freshFor: lifetime - age);
  }

  final staleFor = age - lifetime;
  final swr = control.staleWhileRevalidate;
  if (swr != null && staleFor <= swr && !control.mustRevalidate) {
    return CacheDecision(
      verdict: CacheVerdict.staleUsable,
      age: age,
      reason: 'stale by ${staleFor.inSeconds}s, within stale-while-revalidate',
    );
  }
  final sie = control.staleIfError;
  if (sie != null && staleFor <= sie) {
    return CacheDecision(
      verdict: CacheVerdict.staleForErrorOnly,
      age: age,
      reason: 'stale by ${staleFor.inSeconds}s, usable only if revalidation fails',
    );
  }
  if (!facts.hasValidator) {
    return CacheDecision(verdict: CacheVerdict.unusable, age: age, reason: 'stale with no validator to revalidate');
  }
  return CacheDecision(verdict: CacheVerdict.revalidate, age: age, reason: 'stale by ${staleFor.inSeconds}s');
}

Duration? _fromExpires(StoredResponseFacts facts, DateTime at) {
  final expires = facts.expiresHeader;
  final date = facts.dateHeader;
  if (expires == null) {
    return null;
  }
  final base = date ?? facts.storedAt;
  final lifetime = expires.toUtc().difference(base.toUtc());
  if (lifetime.isNegative) {
    return Duration.zero;
  }
  final remaining = lifetime - at.difference(base.toUtc());
  return remaining.isNegative ? Duration.zero : remaining;
}

/// The conditional-request headers a revalidation should carry, or an empty map when there is nothing to send.
///
/// Sent as a pair rather than chosen here because `If-None-Match` wins over `If-Modified-Since` when both
/// exist, and a caller that sends the weaker one gets a full body it then has to compare by hand.
Map<String, String> revalidationHeaders(StoredResponseFacts facts) {
  final etag = facts.etag;
  if (etag != null && etag.isNotEmpty) {
    return <String, String>{'if-none-match': etag};
  }
  final modified = facts.lastModified;
  if (modified != null) {
    return <String, String>{'if-modified-since': _httpDate(modified)};
  }
  return const <String, String>{};
}

/// The IMF-fixdate form HTTP requires, which is not what `DateTime.toIso8601String()` produces.
///
/// Hand-rolled because the alternative is pulling a date-formatting package into an L0 cache, and the format
/// is four fixed fields in English.
String _httpDate(DateTime value) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${weekdays[utc.weekday - 1]}, ${two(utc.day)} ${months[utc.month - 1]} ${utc.year} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} GMT';
}

/// Parses an HTTP date header, accepting the three forms servers actually send.
///
/// Returns null rather than throwing: an unparsable `Date` means the age is unknown, which is a weaker fact
/// than a crash and is handled by falling back to the stored time.
DateTime? parseHttpDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final text = value.trim();
  final iso = DateTime.tryParse(text);
  if (iso != null) {
    return iso.toUtc();
  }
  // "Sun, 06 Nov 1994 08:49:37 GMT" and the two obsolete variants differ only in separators and month names.
  final match = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})\s+(\d{2}):(\d{2}):(\d{2})').firstMatch(text);
  if (match == null) {
    return null;
  }
  const months = <String>['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  final month = months.indexOf(match.group(2)!.toLowerCase());
  if (month < 0) {
    return null;
  }
  var year = int.parse(match.group(3)!);
  if (year < 100) {
    // A two-digit year in an HTTP date is a bug on the server; RFC 6265's window puts 00-69 in this century.
    year += year <= 69 ? 2000 : 1900;
  }
  return DateTime.utc(
    year,
    month + 1,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
