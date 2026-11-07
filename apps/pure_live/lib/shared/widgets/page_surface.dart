import 'package:flutter/widgets.dart';

import 'package:pure_live/app/configuration/env.dart' show Env;
import 'package:pure_live/layouts/tv/tv_page_shell.dart' show TvPageShell;

/// The invisible surface every routed page sits on.
///
/// Flutter gives each route a transparent `ModalBarrier` behind its page, and
/// that barrier is not dismissible: when a click reaches it, the framework
/// answers with the platform's alert sound — the Windows "ding" — instead of
/// doing nothing. A page covers the barrier only where its own widgets reach,
/// so an empty page, an empty state or the gaps beside a column let the click
/// fall through to it.
///
/// This layer paints nothing, so the wallpaper and the shell's background keep
/// showing through, but it takes the pointer: a click that no control wanted
/// stops here instead of ringing the system alert.
///
/// A TV build also hangs the page's D-pad shell here, so every pushed route
/// carries the focus plumbing in one place: a covered page leaves the focus
/// tree, the opening highlight lands on the page's own first row, and focus
/// comes back to the row the viewer acted on when a dialog above pops.
final class PageSurface extends StatelessWidget {
  /// Wraps [child] in the page's pointer-absorbing surface.
  const PageSurface({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = ColoredBox(color: const Color(0x00000000), child: child);
    if (!Env.isTv) return surface;
    return TvPageShell(child: surface);
  }
}
