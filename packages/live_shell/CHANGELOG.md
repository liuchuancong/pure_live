# Changelog

## Unreleased

### Added

- Desktop shell decisions: close disposition, quit ledger, window geometry with
  display clamping, chrome plan and hit testing, startup mode, idle reclaim policy
  and `ReclaimCircuit`, secondary-window role rules, launch intents over a loopback
  socket, sign-in and file-association registration, and the `DesktopShell`
  orchestrator.
- `intentForHandoff`: launching an already-running instance with no arguments is
  itself a request to show the window, so a hidden app cannot become unreachable.

### Changed

- `DesktopShell` reads the maximised state from the host at geometry time rather
  than remembering which event last arrived, and records before hiding, reclaiming
  or quitting — a programmatic maximise reports no event on Windows, so an
  event-tracked flag stored the maximised rectangle as the restore size.

### Breaking Changes

- Initial development release; no stability commitment yet.
