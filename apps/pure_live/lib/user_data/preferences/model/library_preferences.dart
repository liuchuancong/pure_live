import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_preferences.freezed.dart';
part 'library_preferences.g.dart';

/// How live room lists (recommend, category, search, follow) lay out.
enum LiveListLayout {
  /// A grid of cover cards.
  grid,

  /// A one-column list of rows.
  list,
}

/// Library preferences: the room lists and the watch history bounds.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LibraryPreferences with _$LibraryPreferences {
  /// Library preferences with the shipping defaults.
  const factory LibraryPreferences({
    /// The layout of the live room lists.
    @Default(LiveListLayout.grid) LiveListLayout listLayout,

    /// How many columns the grid uses; ignored in list layout.
    @Default(2) int gridColumns,

    /// How many watch history entries are kept, oldest evicted first.
    @Default(300) int historyLimit,
  }) = _LibraryPreferences;

  /// Restores library preferences from JSON.
  factory LibraryPreferences.fromJson(Map<String, Object?> json) => _$LibraryPreferencesFromJson(json);
}
