import 'package:flutter/widgets.dart';

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
final class PageSurface extends StatelessWidget {
  /// Wraps [child] in the page's pointer-absorbing surface.
  const PageSurface({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: const Color(0x00000000), child: child);
}
