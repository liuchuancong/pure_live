
# Changelog

## 0.1.0

- Establish the initial PureLive utility package.
- Define module boundaries and public API conventions.
- `async_tools` became `async` and gained `CancellationToken` with `OperationCancelledException` (moved
  out of `retry.dart`, which now re-exports it), `AsyncOnce<T>` (one stored computation per key, failures
  not remembered), `Disposer`/`Disposable` and `OperationGuard`.
- New modules, each absorbed from measured duplication: `errors` (`DomainFailure`, `UnexpectedFailure`),
  `conversion` (`intFrom`, `doubleFrom`, `boolFrom`, `stringFrom`, `jsonMapFrom`, `stringListFrom`),
  `numbers` (`clampInt`, `clampDouble`, `lerpDouble`, `roundTo`, `percentOf`, `ByteSize`), `types` (`Unit`,
  `asOrNull`, `or`), `validation` (`requireNonBlank`, `requireInRange`, `requireNotEmpty`,
  `requireNonNull`), `equality` (`ValueEquality`, `deepEquals`, `deepHash`), `identifiers` (`identityKey`,
  `normalizeToken`, `sameToken`) and `math` (`ClosedInterval`).
- **Breaking**: `result` split — `ResultCollection`, `partition`, `collect` and `waitAll` moved to
  `result_sequence.dart`; `result_transformers.dart` now holds the throwing-to-`Result` seam
  (`captureResult`, `captureAsync`) and the future combinators (`andThen`, `recover`).
- **Breaking**: `waitAll()` no longer folds a rejected future into the error list. A rejection means the
  caller did not turn its own failure into `Result.err`, so it propagates.
- `AsyncMemoizer` evicts in store order instead of by `storedAt` comparison, which picked the newest entry
  when two writes landed in the same clock tick.
- Dropped the `collection` dependency; `clock` is the only runtime dependency.
