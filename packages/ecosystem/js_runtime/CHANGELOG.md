# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Fixed**:`start()` was not single-flight and leaked the engine on partial failure. Two concurrent starts both
  passed the `_engine != null` check across the awaits and created two native engines, one of which no one held
  a handle to; if `init`, a resource-limit call or the prelude eval threw, the created engine kept running while
  `_engine` stayed null, so `dispose()` had nothing to close. `LibFjs.init()` had the same race and cached a
  failure as "initialised".
- **Fixed**:`evaluateModuleSource` called the engine directly - no concurrency slot, no timeout. A module whose
  top-level code hung waited forever: the deadline the policy promises did not apply to loading, which is
  exactly where untrusted code runs. Every evaluation now passes one shared gate.
- **Fixed**:`dispose()` closed the engine with evaluations in flight, so those calls failed in whichever way the
  native layer chose and the caller's future resolved as a crash instead of an answer. It waits for a grace
  period (the evaluation's own timeout budget) before closing.
- The concurrency-exhausted message interpolated nothing: `\${policy.limits.maxConcurrentScripts}` is an escaped
  literal, so the diagnostic always showed the source text instead of the budget.
- An `http` answer is now size-checked **before** `utf8.decode`, against the same `maxOutputBytes` the script
  output already had. Decoding 200 MB and then reporting "output too large" is an OOM walking in through the door
  the limit was meant to block.
- **Breaking**: `extendedApiHandler` returning null means "I do not speak this api", and is turned into the named
  `unknown host api` error. It used to be handed to the script as a successful call that answered nothing.
- **Breaking**: a capability method nothing implements is reported by a structured marker from the prelude and a
  `NoRegistration` type on the Dart side. The host used to decide that by matching the *wording* of a thrown
  message, so a text change turned an optional method into a hard failure.
- A page is no longer lost to one bad row: `_pageFrom` and `categories()` used `_asObjectMap(row)!` and
  `ContentSummary.fromJson` unguarded, so a string in the list or a row missing its ref threw away every result
  the plugin had returned - an empty page where a partial one is the truth. Describing itself as a non-list, or
  `capabilityNames` as a non-array, is a broken plugin rather than a host crash, and an unreadable ticket names
  its group and method.
- `registeredGroups` returns an unmodifiable snapshot; it exposed the live set, so any caller could grant the
  plugin a group its manifest never declared, or clear the runtime's state through a getter.
- A failed `load()` no longer leaves the runtime holding the manifest and the host bridge of a plugin that never
  started.
- README gained the 结构 and 行为契约 sections, and its 验证 section stopped claiming `dart test` runs here: fjs is
  a Flutter FFI plugin, so nothing in this package has been executed - stated as such under 未验证.

- Earlier: skeleton created for layer ecosystem as `pure_live_js_runtime`, then the fjs sandbox and plugin runtime.
