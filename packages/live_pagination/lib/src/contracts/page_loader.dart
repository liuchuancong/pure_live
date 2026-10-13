import 'package:live_pagination/src/contracts/page_request.dart';
import 'package:live_pagination/src/contracts/page_result.dart';

/// Produces one ready-made logical page.
///
/// This is the single integration point between the pagination core and
/// any data source. Implementations (usually closures over a repository)
/// own everything source-specific:
///
/// - remote page APIs — request the page directly;
/// - variable-length server batches — aggregate as many batch calls as
///   the logical page needs (the core never loops for you);
/// - complete server data — cache the snapshot and slice;
/// - cursors — advance them per your continuation rules;
/// - local databases — query or slice.
///
/// Errors are reported by throwing; controllers catch, store the error
/// on their state and keep the previously shown data. A loader that
/// cannot jump to an arbitrary page (e.g. a forward-only cursor) simply
/// makes that known to the UI layer — controllers expose
/// `supportsJumpToPage` so desktop navigation can be disabled honestly
/// instead of pretending every source has the same abilities.
typedef PageLoader<T> = Future<PageResult<T>> Function(PageRequest request);
