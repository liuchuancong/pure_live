import 'package:flutter/widgets.dart';

/// The host a TV surface hands the app's dialogs and panels to, bound by
/// the app once per window. On that window's TV form factor the opener
/// takes the TV dialog's shape — the remote lock, the focus guard, the way
/// back to the item that opened it — and off it the binder answers null and
/// the plain dialog stands. A shared file cannot read the app's providers,
/// so the decision rides this seam, the way the proxy lookup and the
/// recording tap do.
typedef AppDialogHost = Future<T?>? Function<T>(BuildContext context, WidgetBuilder builder, {bool dismissible});

/// The bound host, or null while none is (a test, a plain window).
AppDialogHost? appDialogHost;
