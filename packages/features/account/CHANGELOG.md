# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking**: `SiteAccountRegistry` became `CredentialSiteAccounts` implementing the new
  `SiteAccountRepository`; `SiteAccountStatus` became `SiteAccount` (per account, not per site).
- **Fixed**: `load(siteId)` fabricated a `CredentialHandle` by string convention
  (`'$siteId:$accountId'`) instead of using the stored one. The real vault key is prefixed, so every handle
  this method returned pointed at a key that cannot exist - a signed-in site read as signed out, and a
  caller that used the handle for an authenticated request would have missed its cookie entirely.
- **Fixed**: `logout(siteId)` deleted `accounts.last`, silently choosing one account of a multi-account
  site. Explicit per-account `signOut(SiteAccount)` and a separately named `signOutSite(siteId)` now exist,
  and the latter clears every account of the site rather than stopping at the first failure.
- `expiresAt` in the old status type was declared but never populated. Status now comes from the stored
  session, so `expired`, `disabled` and "no account" are distinguishable, and `canRefresh` says which of
  them is worth a refresh instead of a re-login.
- Added `secretPresent`: a session record whose credential vanished is a partial wipe, not a logout, and it
  must not be reported as either.
- Added the limits the store would have accepted anyway: blank site or account ids are rejected, an empty
  secret is rejected, and a secret larger than `maxSecretSize` (default 64 KiB) is refused with the actual
  and permitted sizes in the message - an unbounded write fills secure storage and then breaks every other
  site's login.
- `accountsOf` is ordered by account id so a d-pad aims at the same row after a restart, and
  `primaryAccount` picks the usable session living longest, falling back to the most refreshable one.
- `markStatus` reports `AccountNotFoundFailure` where the store quietly ignored a missing record.
- Declared `pure_live_utils` and the `test` dev dependency.
