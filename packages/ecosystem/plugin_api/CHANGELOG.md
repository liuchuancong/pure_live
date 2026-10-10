# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Corrected an overstated comment: `knownCapabilities` claimed "the test suite pins this list against
  `CapabilityKind` in pure_live_capability". No such test exists and none can — plugin_api must not depend on
  capability (same-layer rule), so the two vocabularies are each pinned against the document by their own
  package's tests. The comment now says that, and the README lists the drift risk as what it is: a review
  obligation rather than a covered case.
- README gained 平台矩阵 and 未验证 sections; the 未验证 list states plainly that no implementation of
  `PluginRuntime`/`ScriptSandbox` has ever been tested, because the only implementation (js_runtime) has zero
  tests.

- Skeleton created for layer ecosystem as `pure_live_plugin_api`: no dependencies and no implementation yet.
