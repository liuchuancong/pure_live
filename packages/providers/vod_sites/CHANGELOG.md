# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Added**: the package, as the点播 counterpart of `pure_live_sites`: one directory per site, two files per site
  (`<site>_api.dart` + `<site>_site.dart`), shared platform models as return values.
- **Moved**: `bilibili.vod` out of `pure_live_bilibili`. Live sites and VOD are different objects - a room's
  address carries a lease that can end an established stream, a video's can simply be re-minted - so they do not
  share a `resolve` implementation or a package. Source id, `cid`/`bvid` metadata keys and every answer shape are
  unchanged; only the import surface moved.
- **Changed**: the WBI file is now `bilibili_api.dart` and owns the endpoint urls and the browser headers with the
  signing recipe, so a moved endpoint has one definition to change.
