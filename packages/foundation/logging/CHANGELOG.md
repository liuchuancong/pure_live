# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `redaction.dart`: field scrubbing split out of `record.dart` and widened. A **free-text** credential was the
  gap: `NetworkClient` logs `playUrl`, and a header map that says `Authorization: Bearer <token>` had its first
  word masked and its second one kept. Names are matched as whole words now - a substring rule masked `design:`
  because it contains `sign`, which teaches nobody to trust a log.
- `sinks.dart`: `RotatingFileSink` (byte-capped, numbered rolloff, failures counted instead of thrown back into
  the code path that is already failing), `RateLimitedSink` (per `level|logger|message` fingerprint window,
  with a line that says how many were suppressed), `BufferedSink` (bounded drain queue) and `JsonLineSink`.
- `MemoryLogSink` is bounded (default 1000) with a `droppedCount`: an in-memory log view that keeps everything
  is the out-of-memory report it is meant to explain.
- `LogRouter` takes an injectable `Clock` - records used to stamp `DateTime.now()`, so a timestamp could not be
  asserted without sleeping - and isolates a throwing sink through `onDispatchError` instead of letting one
  broken file sink take the console down with it.
- `Logger.withFields` for a derived logger carrying session/room context through every line, scrubbed like any
  other field. `formatRecordJson` shares `LogRecord.toJson`, so file and console cannot disagree.
- Platform note: this package imports `dart:io` (stdout and file rotation) and is therefore not web-safe.
