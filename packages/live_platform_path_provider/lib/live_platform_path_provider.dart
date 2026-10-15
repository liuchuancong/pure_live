/// Path and storage layer for Pure Live.
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
/// check when data exists in two trees) and `AtomicFileWriter` (crash-safe
/// replacement). User-picked files flow through `FileAccessService`.
library;

export 'src/bootstrap/path_provider_bootstrap.dart';
export 'src/conflicts/storage_conflicts.dart';
export 'src/contracts/file_access_service.dart';
export 'src/contracts/platform_exception.dart';
export 'src/contracts/storage_area.dart';
export 'src/contracts/storage_location.dart';
export 'src/contracts/storage_manager.dart';
export 'src/diagnostics/storage_diagnostics.dart';
export 'src/insights/path_insights.dart';
export 'src/insights/path_privacy.dart';
export 'src/storage/atomic_file_writer.dart';
export 'src/storage/default_storage_manager.dart';
export 'src/storage/storage_policy.dart';
