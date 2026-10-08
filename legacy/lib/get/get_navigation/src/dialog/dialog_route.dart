import 'package:flutter/widgets.dart';

import '../router_report.dart';

class GetDialogRoute<T> extends PopupRoute<T> {
  GetDialogRoute({
    required RoutePageBuilder pageBuilder,
    this.barrierDismissible = true,
    this.barrierLabel,
    this.barrierColor = const Color(0x80000000),
    this.transitionDuration = const Duration(milliseconds: 200),
    this.transitionBuilder,
    super.settings,
  }) : widget = pageBuilder {
    RouterReportManager.instance.reportCurrentRoute(this);
  }

  final RoutePageBuilder widget;

  @override
  final bool barrierDismissible;

  @override
  void dispose() {
    RouterReportManager.instance.reportRouteDispose(this);
    super.dispose();
  }

  @override
  final String? barrierLabel;

  @override
  final Color barrierColor;

  @override
  final Duration transitionDuration;

  final RouteTransitionsBuilder? transitionBuilder;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: widget(context, animation, secondaryAnimation),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (transitionBuilder == null) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.linear),
        child: child,
      );
    } // Some default transition
    return transitionBuilder!(context, animation, secondaryAnimation, child);
  }
}
