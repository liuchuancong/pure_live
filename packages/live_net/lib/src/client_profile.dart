/// The business scenario a network client serves.
///
/// A profile picks the pipeline defaults — caching, retries, cookie
/// handling — so call sites never tune raw interceptor settings. The
/// defaults live in `DioFactory`; a profile is an identity, not a
/// configuration system. Request-level overrides (`LiveRequest.cache`,
/// `LiveRequest.idempotent`) refine a profile for single calls.
enum ClientProfile {
  /// Fixed REST APIs: caching is enabled per endpoint, idempotent verbs
  /// get bounded retries.
  api,

  /// Live sites and their endpoints: caching happens only where a request
  /// explicitly asks for it, retries follow the request's semantics.
  site,

  /// External plugin requests: conservative defaults — no persistent
  /// cache, strictly limited retries.
  plugin,

  /// Playlists and media segments: signed URLs are never cached, retries
  /// stay cautious.
  media,

  /// Login and token flows: never generically cached, never auto-retried.
  auth,
}
