import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_retraction.freezed.dart';
part 'live_retraction.g.dart';

/// Which earlier messages a `LiveMessageType.retraction` takes back.
///
/// Exactly one targeting mode is set: a specific user (by id or, when the
/// platform only names them, by display name), a specific message, or the
/// whole chat.
@freezed
abstract class LiveRetraction with _$LiveRetraction {
  /// Creates a LiveRetraction with already-normalized fields.
  const factory LiveRetraction({String? userId, String? messageId, @Default(false) bool all}) = _LiveRetraction;

  const LiveRetraction._();

  /// Deserializes a stored JSON record.
  factory LiveRetraction.fromJson(Map<String, Object?> json) => _$LiveRetractionFromJson(json);

  /// Whether this retraction targets the message shown for the given sender
  /// or id.
  bool matches({String? userId, String? userName, String? messageId}) {
    if (all) return true;
    final target = this.userId?.trim().toLowerCase();
    if (target != null && target.isNotEmpty) {
      if (userId != null && userId.trim().toLowerCase() == target) return true;
      if (userName != null && userName.trim().toLowerCase() == target) return true;
    }
    final id = this.messageId;
    return id != null && messageId != null && messageId == id;
  }
}
