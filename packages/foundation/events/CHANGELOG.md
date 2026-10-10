# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `EventBus.observe` — a hook that sees every emit, including the ones with no listener. Diagnostics had to
  subscribe to `on<AppEvent>()` to watch the bus, which meant a dropped event was invisible exactly when
  nothing was listening: the case a "why did nothing happen" report is about.
- Bounded diagnostics: `recentEvents` (a ring of `kEventLedgerLimit`), `countOf(name)`, `emissionCounts` and
  `channelCount`. An unbounded ledger is the memory problem the diagnosis was supposed to find.
- `subscribe<T>(handler, into:)` registers the handle with a `Disposer`; `onReplaying<T>(length)` serves the
  screen that opens after the fact it needed; `expect<T>(within)` waits instead of polling with a sleep.
- `operators.dart`: `throttled`, `coalescedBy`, `debounced`, `buffered`, `named`, `fresherThan` — each with a
  trailing pass or a second flush trigger, because a throttle that swallows the last event loses the value the
  user stopped on, and a buffer with one trigger either never flushes or holds a flood.
- `sinks.dart`: `EventLogSink` (name and time only, never the payload; self-suspending flood guard that
  reports it suspended), `EventRecorder`, `EventPublisher` (stamps with an injected `Clock`).
- `pubspec.yaml`: the `utils` and `logging` leaves added, for the sinks and the clock.

- `EventBus`: one broadcast channel **per event type** instead of one per `on<T>()` call. The previous
  version allocated a controller for every call and retained it until `dispose()`, so a screen that
  subscribed on each rebuild grew the bus without bound and kept dropped subscriptions reachable. The
  bound is now the number of event classes, which is the only bound this layer can know without owning a
  lifecycle it does not have.
- **Breaking**: `hasListeners` answers "is anything subscribed at all" (it previously claimed to answer for a
  type it could not see, being a getter). `hasListenersFor<T>()` is the type-specific question.
- **Fixed**: `sync: true` ran each listener's callback inside `emit`, so one throwing listener propagated its
  error through the publisher and stopped every later subscriber - a settings page's bug could mute an
  auth-expiry event. Delivery is asynchronous now; the error belongs to the zone that created the
  subscription, and the bus keeps serving everyone else.
- `dispose()` is idempotent, and `on<T>()` / `emit()` after disposal are inert instead of throwing.
