import 'package:flutter/foundation.dart';
import 'package:pure_live/common/models/live_room.dart';

@immutable
class RoomState {
  static const Object _notProvided = Object();
  final LiveRoom? detail;
  final bool isLiving;
  final bool success;
  final bool isLoading;
  final String? loadError;

  const RoomState({this.detail, this.isLiving = true, this.success = false, this.isLoading = false, this.loadError});

  bool get hasRoom => detail != null;

  RoomState copyWith({
    LiveRoom? detail,
    bool? isLiving,
    bool? success,
    bool? isLoading,
    Object? loadError = _notProvided,
  }) {
    return RoomState(
      detail: detail ?? this.detail,
      isLiving: isLiving ?? this.isLiving,
      success: success ?? this.success,
      isLoading: isLoading ?? this.isLoading,
      loadError: identical(loadError, _notProvided) ? this.loadError : loadError as String?,
    );
  }

  RoomState clearError() {
    return RoomState(detail: detail, isLiving: isLiving, success: success, isLoading: isLoading, loadError: null);
  }
}
