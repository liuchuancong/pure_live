import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_status.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Stores `LiveStatus` as its name string; reads legacy v1 index ints too.
///
/// Index storage breaks whenever an enum value is inserted; names survive
/// (ARCHITECTURE.md §12).
final class LiveStatusByNameConverter implements JsonConverter<LiveStatus?, Object?> {
  /// Creates a const converter instance for field annotations.
  const LiveStatusByNameConverter();

  @override
  LiveStatus? fromJson(Object? json) => switch (json) {
    final String name => LiveStatus.values.where((v) => v.name == name).firstOrNull,
    final int index when index >= 0 && index < LiveStatus.values.length => LiveStatus.values[index],
    _ => null,
  };

  @override
  Object? toJson(LiveStatus? value) => value?.name;
}
