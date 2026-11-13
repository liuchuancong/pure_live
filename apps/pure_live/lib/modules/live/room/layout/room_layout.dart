/// The room's layout machine: the window class and the sideways-phone flag,
/// resolved once from the window's shape and read by every branch instead of
/// each deriving its own measures.
///
/// The class axis is the width (wide from 840, regular from 600, compact
/// under). A phone-like device held sideways in a short window is the
/// landscape arrangement before any width is asked — the compact height wins
/// over the wide breakpoint. A desktop window as short keeps the class its
/// width gives it.
library;

/// The width the room's wide arrangements start at; the chat column's toggle
/// and the `T` key answer to the same measure.
const double kRoomWideBreakpoint = 840;

/// The width where a narrow window's own arrangements start; under it the
/// room is compact.
const double kRoomCompactBreakpoint = 600;

/// Windows shorter than this are a phone held sideways, whatever their width
/// (the reference's compact height, which wins over the wide breakpoint).
const double kRoomLandscapeMaxHeight = 480;

/// The window classes the room's arrangements answer to, wide to compact.
enum RoomWindowClass { wide, regular, compact }

/// One resolution of the room's layout axes.
final class RoomLayout {
  const RoomLayout._({required this.windowClass, required this.landscapePhone});

  /// Resolves the axes from the window's shape. [phoneLike] marks a phone or
  /// tablet runtime — a desktop window held short keeps its width's class.
  factory RoomLayout.resolve({required double width, required double height, required bool phoneLike}) {
    final landscapePhone =
        phoneLike && height < kRoomLandscapeMaxHeight && width > height && width >= kRoomCompactBreakpoint;
    final windowClass = switch (width) {
      >= kRoomWideBreakpoint => RoomWindowClass.wide,
      >= kRoomCompactBreakpoint => RoomWindowClass.regular,
      _ => RoomWindowClass.compact,
    };
    return RoomLayout._(windowClass: windowClass, landscapePhone: landscapePhone);
  }

  /// The width's class: wide from 840, regular from 600, compact under.
  final RoomWindowClass windowClass;

  /// A phone-like device held sideways in a short window: its own
  /// arrangement, decided before the width's class is asked.
  final bool landscapePhone;
}
