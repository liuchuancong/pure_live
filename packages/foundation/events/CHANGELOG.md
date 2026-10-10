# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

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
