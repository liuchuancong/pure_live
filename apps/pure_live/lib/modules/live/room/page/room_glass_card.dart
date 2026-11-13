import 'package:pure_live/shared/shared.dart' show PlayerGlassCard;

/// The room's frosted card — the shared players' glass surface
/// (`PlayerGlassCard`) under the room's own name, so every room call site
/// keeps its word.
///
/// The widget itself lives in `shared/player` beside the other pieces every
/// player draws; the alias holds the name the room's pages read.
typedef RoomGlassCard = PlayerGlassCard;
