/// The user's room library for Pure Live.
///
/// `FollowRepository` owns the followed rooms, their groups and ordering;
/// `HistoryRepository` keeps the watch history, newest first with a cap.
/// Both persist JSON through the `LibraryStore` seam —
/// `PreferencesLibraryStore` writes through the live_storage preferences
/// store, so a second window sees the same data. The persisted record
/// (`LibraryRoom`) keeps the `LiveRoom` snapshot apart from the user's
/// metadata: a refresh replaces the snapshot only, never the note, groups
/// or position. The package makes no platform calls and holds no UI.
library;

export 'src/model/library_room.dart';
export 'src/repository/follow_repository.dart';
export 'src/repository/history_repository.dart';
export 'src/store/library_store.dart';
