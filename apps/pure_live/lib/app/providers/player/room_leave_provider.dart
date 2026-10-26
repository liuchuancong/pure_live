import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The room's leave verb, overridable per host: the null default pops the
/// route (or goes home when the room is the stack's root, as in a clone).
/// A host that embeds the room in a window it owns can close that window
/// instead.
final roomLeaveProvider = Provider<Future<void> Function()?>((ref) => null);
