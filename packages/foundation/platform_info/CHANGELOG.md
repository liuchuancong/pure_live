# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `PlatformCapabilities` became a value: `operator ==`/`hashCode`, `copyWith`, `restrict` (the intersection two
  targets must both satisfy) and `without`, plus `PlatformCapability`, `enabled` and `supports()` so "which
  switch" is something a call site can pass rather than eight booleans each surface re-reads. Without equality
  every derived row compared as new and the subtree rebuilt.
- `device_profile.dart`: `DeviceForm` and `resolveDeviceForm` (layout classes, with the television declared by
  the host rather than derived from pixels), `DeviceFormLayout.requiresFocusNavigation`, and
  `DeviceDescription.summary()/toJson()` for the diagnostics header with a bounded model string.
- `CapabilityOverride` + `DeviceProfile.resolve`: a per-device-family kill switch that sits beside the table
  instead of inside it. **Only removal is allowed** - granting a capability the table denies is a claim nobody
  verified - and `disabledByOverrides` makes a rule that stopped matching visible.

## Unreleased (2026-10-10, unknown target pass)

- **Breaking**: `detectPlatform` answers a new `PlatformKind.unknown` for an operating system it does not
  recognise, instead of `PlatformKind.web`. The old fallback was commented as "the most restricted target",
  which web is not - a browser may enter picture-in-picture and declares itself touch-first - so an
  unrecognised native fork silently inherited two optimistic answers *and* web's storage assumptions,
  including any `kind == web` branch elsewhere in the app (that question chooses where files go).
- `PlatformCapabilities.unknown` is the floor with nothing set. The exhaustive switch over `PlatformKind` is
  unchanged, so a target added later still fails to compile until someone states its capabilities.
- `capabilitiesFor(web, webIsTouchPrimary: ...)` exists because "web" carries no input information: a phone
  browser and a desktop browser are the same kind with opposite layout rules, and the host is the only party
  that can tell them apart. It changes that one flag and nothing else.
- Documented why tvOS is the only target with neither background audio nor LAN remote control, so a feature
  offering either knows it is drawing a dead button on exactly one platform.
