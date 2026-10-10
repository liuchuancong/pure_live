# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `redaction.dart`: one named rule table for every surface that leaves the device. Each surface used to scrub
  its own subset, so each had a case it missed; `Authorization: Bearer <token>` was the live one here - masking
  only the first word leaves the credential standing behind its own redaction.
- `failure_ledger.dart`: repeats merge into one entry keyed on type + digit-masked first line + first app frame,
  with first/last seen and a per-minute rate. Thirty retries of one dead source were thirty log lines and one bug.
- `metrics.dart`: counters and duration summaries (min/mean/p50/p95/max) with a bounded sample window and a
  bounded label set; a summary that was sampled says so, because a mean-only view hides the one slow request
  that made a session unwatchable.
- `breadcrumbs.dart`: the user's last steps, scrubbed on the way *in* rather than on export.
- `report.dart`: a report with a per-section budget and an overall one, keeping head and tail and writing the
  omission counts into the output; a silent mid-stack stop reads like the trace ended where the buffer did.
- `pubspec.yaml`: the `utils` leaf added, for the injectable `Clock` these take instead of a wall-clock read.

- `RingBuffer` is a real ring: an overwrite advances a head index instead of `removeAt(0)` on a growable
  list, which copied the whole tail on every add once full - and this buffer is written on every diagnostic
  event for the lifetime of a session.
- **Fixed**: `measure` timed with two `DateTime.now()` readings, so a wall-clock step (NTP correction, a
  manual change, a device wake) could report a negative duration; a dashboard reads that as "instant" and a
  threshold check as "safe to ignore". It uses a `Stopwatch` now.
- **Fixed**: `runGuarded` called its handler unguarded, so a reporter that threw - a locked diagnostics file
  is the usual one - left the caller awaiting a future that could never complete. A handler failure is now
  surfaced after the body finished rather than swallowing the body's reason or hanging.
- Added `isFull`, kept `droppedCount` as the "this view is partial" signal.
