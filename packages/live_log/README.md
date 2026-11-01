# live_log

Logging facade for a host application: levelled, categorised records with a
per-sink fan-out, sanitisation before any sink sees a record, and console /
bounded-memory / rotating-file sinks. The core depends only on the Dart SDK,
`path` and `logger`; Flutter integration stays in the app shell.

## Purpose

A log line is read twice — once by a developer chasing a bug, once by a
crash report travelling out of the machine. Both reads are ruined by the same
mistakes: a token or a path printed verbatim, a sink that slows the caller
down, a file that grows forever. This package puts those decisions in one
place: what a record carries (`model/`), how it moves (`pipeline/`), and who
receives it (`sinks/`).

## Responsibilities

- `LiveLog` — the facade a caller talks to: named categories, levelled
  records, context fields, never throwing into the caller's flow.
- Records and models (`model/`) — `LiveRecord`, levels, per-category filters,
  and the formatter that turns a record into a line.
- The pipeline (`pipeline/`) — a dispatcher that fans a record out to every
  sink, a sanitiser that runs before any sink sees the record (tokens, file
  system paths, cookies), and an error reporter hook so an unhandled error
  becomes a record instead of a print.
- Sinks (`sinks/`) — console output, a bounded in-memory ring (what the
  settings page shows), a rotating file sink, a fan-out sink that multiplexes
  the others, and a logger-package adapter.

## What lives where

- `lib/live_log.dart` — the public surface.
- `lib/src/model/` — records, levels, filters, formatting, the sink contract.
- `lib/src/pipeline/` — dispatch, sanitisation, error reporting.
- `lib/src/sinks/` — the concrete sinks.

The package never reads a clock, a file system or a network on its own
beyond the file sink it is explicitly given; everything else arrives
injected, which is what the tests exercise without I/O.
