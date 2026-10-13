import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/core/live_site_error.dart';

/// Runs [action] and converts an unexpected exception into a typed
/// [LiveSiteError] so a boundary always yields an `Either`.
///
/// This is a safety net, not a category classifier: expected business failures
/// should be returned explicitly by [action] as a `Left`, and network or parse
/// failures should already be classified at the layer that sees them (the
/// network client, the parser). Anything reaching the catch here is genuinely
/// unexpected and becomes a [LiveSiteUnexpectedError] carrying the original as
/// its cause.
Future<Either<LiveSiteError, T>> captureLiveSite<T>({
  required String siteId,
  required String operation,
  required Future<T> Function() action,
}) async {
  try {
    return right(await action());
  } on Object catch (error) {
    return left(
      LiveSiteUnexpectedError(siteId: siteId, message: 'Unexpected failure during $operation.', cause: error),
    );
  }
}
