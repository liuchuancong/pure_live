# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

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
