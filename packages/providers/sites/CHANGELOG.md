# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Added**: the package. Every live site is a directory here rather than a package of its own, in the shape the
  reference product uses: `lib/src/<site>/<site>_api.dart` (urls, identity, signing, response readers) and
  `<site>_site.dart` (the capability answers). No per-site model file - callers receive the shared
  `pure_live_platform` models.
- **Added**: `common/site_json.dart`, the reading rules the sites share. A field arrives as a map, a number, a
  numeric string, a `{value: …}` box or absent, and *absent is not zero*: an unknown viewer count drawn as `0` is
  a number the source never claimed, and a page whose rows failed to parse shown as "no rows" is a lie a pager
  follows.
- **Moved**: `huya.live` and `douyu.live` from their own packages (`pure_live_huya`, `pure_live_douyu`), which
  existed only while there were two sites. Source ids, ticket metadata keys and the shape of every answer are
  unchanged - only the import surface moved.
