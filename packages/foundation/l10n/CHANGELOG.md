# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Skeleton created for layer foundation as `pure_live_l10n`: no dependencies and no implementation yet.
- `plural_math.dart`: the CLDR plural operands (n, i, v, w, f, t, e), because the published rules are stated
  over operands and an `int`-only count mis-renders `1.0 kg`, `2,5` and `1e3`.
- `plural_rules.dart`: cardinal plural tables for ~30 languages replacing the four-entry rule set, plus
  `requiredCategories` / `requiredFormNames` so a translation file can be checked before it ships.
  `pluralCategory` and `pluralize` moved here from `locale.dart` and now delegate to the same table, so the
  package has one plural implementation instead of two that disagree about French.
- `message_format.dart`: an ICU-subset parser (named arguments, `plural`, `select`, `=N`, `#`, escaped
  braces) that reports problems instead of throwing, so a catalog can refuse a bad entry at load time.
- `catalog.dart`: `LocalizationCatalog` with owner-namespaced keys, per-language bundles carrying plural
  forms, load-time validation (missing `other`, missing required form, dropped argument, orphaned key),
  coverage and orphan reporting, a capped problem ledger, and locale number/date rendering.
- `relative_time.dart`: `RelativeSpan` bucketing with calendar-counted months and years, and
  `RelativeTimeFormatter` over a host-supplied `RelativePhrases` table - the package holds no strings.
- `pubspec.yaml`: `intl: ^0.20.0` added for the locale symbol tables only.
