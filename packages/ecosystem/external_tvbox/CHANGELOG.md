# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Declared `pure_live_plugin_api`: `js_spider_handle.dart` and `js_drpy_spider_handle.dart` build a sandbox and
  so name `SandboxPolicy`/`SandboxUnit`, which are plugin_api's contract. The import existed for a long time
  without the declaration — a pub workspace resolves it anyway, which is exactly why the architecture guard now
  reports `undeclared-dependency` (docs/architecture/dependency-rules.md §4.1). The same-layer edge is on the
  §4 whitelist beside the JS host's own `js_runtime → plugin_api`.
- No behaviour change; the package's own implementation is unchanged by this entry.
- Skeleton created for layer ecosystem as `pure_live_external_tvbox`: no dependencies and no implementation yet.
