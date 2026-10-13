/// Pagination core for Pure Live.
///
/// One engine behind two interaction models: desktop numbered pagination
/// (`PagedController` — exactly one visible page, jumps, previous/next)
/// and mobile infinite scrolling (`InfiniteController` — accumulated
/// pages, refresh rebuilds, append resume). Both consume the same
/// `PageLoader` contract: a loader receives a logical `PageRequest` and
/// returns the ready-made `PageResult` for that page — batch
/// aggregation, cursor handling and slicing stay inside the loader, and
/// the core never issues follow-up requests on its own.
///
/// The package depends on nothing but `meta`; HTTP, repositories,
/// Riverpod and widgets live above it.
library;

export 'src/config/pagination_view_config.dart';
export 'src/contracts/page_loader.dart';
export 'src/contracts/page_request.dart';
export 'src/contracts/page_result.dart';
export 'src/contracts/pagination_session.dart';
export 'src/controller/infinite_controller.dart';
export 'src/controller/paged_controller.dart';
export 'src/math/page_math.dart';
export 'src/state/infinite_state.dart';
export 'src/state/paged_state.dart';
export 'src/state/refresh_position_policy.dart';
