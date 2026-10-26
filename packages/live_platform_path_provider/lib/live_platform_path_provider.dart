/// Path and storage layer for whichever application hosts it.
///
/// This package answers "where does this kind of data live, and may we
/// write there" from the deployment facts `live_platform` produced: a
/// portable build resolves its persistent areas under its own executable
/// and never into the OS application directories, an installed build never
/// writes next to the executable, and every resolution is probed with a
/// real write before it is trusted.
///
/// On top of resolution it carries the small, sharp tools the download and
/// migration flows need: `PathPrivacy` (is this path invisible to other
/// apps — prompt the user before downloading there), `PathInsights`
/// (existence and shape of a path), `StorageConflicts` (the split-brain
/// check when data exists in two trees), `StorageAdoption` (carrying a
/// previous tree into the one a new layout resolved, at boot while nothing
/// is open yet) and `AtomicFileWriter` (crash-safe replacement).
/// User-picked files flow through `FileAccessService`.
library;

export 'src/bootstrap/path_provider_bootstrap.dart';
export 'src/conflicts/storage_conflicts.dart';
export 'src/contracts/contracts.dart';
export 'src/diagnostics/storage_diagnostics.dart';
export 'src/insights/insights.dart';
export 'src/migration/storage_adoption.dart';
export 'src/storage/storage.dart';
