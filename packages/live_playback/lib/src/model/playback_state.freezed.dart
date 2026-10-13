// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackState {

 PlaybackPhase get phase;/// The label of the quality being played.
 String? get qualityLabel;/// The id of the line being played.
 String? get lineId;/// How many recovery attempts have been spent.
 int get recoveryAttempts;/// The failure that led to the current recovery, if any.
 PlaybackFailure? get lastFailure;
/// Create a copy of PlaybackState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackStateCopyWith<PlaybackState> get copyWith => _$PlaybackStateCopyWithImpl<PlaybackState>(this as PlaybackState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaybackState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackState&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.qualityLabel, _this.qualityLabel) || other.qualityLabel == _this.qualityLabel)&&(identical(other.lineId, _this.lineId) || other.lineId == _this.lineId)&&(identical(other.recoveryAttempts, _this.recoveryAttempts) || other.recoveryAttempts == _this.recoveryAttempts)&&(identical(other.lastFailure, _this.lastFailure) || other.lastFailure == _this.lastFailure));
}


@override
int get hashCode {
  final _this = this as PlaybackState;
  return Object.hash(runtimeType,_this.phase,_this.qualityLabel,_this.lineId,_this.recoveryAttempts,_this.lastFailure);
}

@override
String toString() {
  final _this = this as PlaybackState;
  return 'PlaybackState(phase: ${_this.phase}, qualityLabel: ${_this.qualityLabel}, lineId: ${_this.lineId}, recoveryAttempts: ${_this.recoveryAttempts}, lastFailure: ${_this.lastFailure})';
}


}

/// @nodoc
abstract mixin class $PlaybackStateCopyWith<$Res>  {
  factory $PlaybackStateCopyWith(PlaybackState value, $Res Function(PlaybackState) _then) = _$PlaybackStateCopyWithImpl;
@useResult
$Res call({
 PlaybackPhase phase, String? qualityLabel, String? lineId, int recoveryAttempts, PlaybackFailure? lastFailure
});


$PlaybackFailureCopyWith<$Res>? get lastFailure;

}
/// @nodoc
class _$PlaybackStateCopyWithImpl<$Res>
    implements $PlaybackStateCopyWith<$Res> {
  _$PlaybackStateCopyWithImpl(this._self, this._then);

  final PlaybackState _self;
  final $Res Function(PlaybackState) _then;

/// Create a copy of PlaybackState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? qualityLabel = freezed,Object? lineId = freezed,Object? recoveryAttempts = null,Object? lastFailure = freezed,}) {
  return _then(PlaybackState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as PlaybackPhase,qualityLabel: freezed == qualityLabel ? _self.qualityLabel : qualityLabel // ignore: cast_nullable_to_non_nullable
as String?,lineId: freezed == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String?,recoveryAttempts: null == recoveryAttempts ? _self.recoveryAttempts : recoveryAttempts // ignore: cast_nullable_to_non_nullable
as int,lastFailure: freezed == lastFailure ? _self.lastFailure : lastFailure // ignore: cast_nullable_to_non_nullable
as PlaybackFailure?,
  ));
}
/// Create a copy of PlaybackState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackFailureCopyWith<$Res>? get lastFailure {
    if (_self.lastFailure == null) {
    return null;
  }

  return $PlaybackFailureCopyWith<$Res>(_self.lastFailure!, (value) {
    return _then(_self.copyWith(lastFailure: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlaybackState].
extension PlaybackStatePatterns on PlaybackState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackState value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackState value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlaybackPhase phase,  String? qualityLabel,  String? lineId,  int recoveryAttempts,  PlaybackFailure? lastFailure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackState() when $default != null:
return $default(_that.phase,_that.qualityLabel,_that.lineId,_that.recoveryAttempts,_that.lastFailure);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlaybackPhase phase,  String? qualityLabel,  String? lineId,  int recoveryAttempts,  PlaybackFailure? lastFailure)  $default,) {final _that = this;
switch (_that) {
case _PlaybackState():
return $default(_that.phase,_that.qualityLabel,_that.lineId,_that.recoveryAttempts,_that.lastFailure);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlaybackPhase phase,  String? qualityLabel,  String? lineId,  int recoveryAttempts,  PlaybackFailure? lastFailure)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackState() when $default != null:
return $default(_that.phase,_that.qualityLabel,_that.lineId,_that.recoveryAttempts,_that.lastFailure);case _:
  return null;

}
}

}

/// @nodoc


class _PlaybackState extends PlaybackState {
  const _PlaybackState({this.phase = PlaybackPhase.idle, this.qualityLabel, this.lineId, this.recoveryAttempts = 0, this.lastFailure}): super._();
  

@override@JsonKey() final  PlaybackPhase phase;
/// The label of the quality being played.
@override final  String? qualityLabel;
/// The id of the line being played.
@override final  String? lineId;
/// How many recovery attempts have been spent.
@override@JsonKey() final  int recoveryAttempts;
/// The failure that led to the current recovery, if any.
@override final  PlaybackFailure? lastFailure;

/// Create a copy of PlaybackState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackStateCopyWith<_PlaybackState> get copyWith => __$PlaybackStateCopyWithImpl<_PlaybackState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.qualityLabel, qualityLabel) || other.qualityLabel == qualityLabel)&&(identical(other.lineId, lineId) || other.lineId == lineId)&&(identical(other.recoveryAttempts, recoveryAttempts) || other.recoveryAttempts == recoveryAttempts)&&(identical(other.lastFailure, lastFailure) || other.lastFailure == lastFailure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phase,qualityLabel,lineId,recoveryAttempts,lastFailure);
}

@override
String toString() {
    return 'PlaybackState(phase: $phase, qualityLabel: $qualityLabel, lineId: $lineId, recoveryAttempts: $recoveryAttempts, lastFailure: $lastFailure)';
}


}

/// @nodoc
abstract mixin class _$PlaybackStateCopyWith<$Res> implements $PlaybackStateCopyWith<$Res> {
  factory _$PlaybackStateCopyWith(_PlaybackState value, $Res Function(_PlaybackState) _then) = __$PlaybackStateCopyWithImpl;
@override @useResult
$Res call({
 PlaybackPhase phase, String? qualityLabel, String? lineId, int recoveryAttempts, PlaybackFailure? lastFailure
});


@override $PlaybackFailureCopyWith<$Res>? get lastFailure;

}
/// @nodoc
class __$PlaybackStateCopyWithImpl<$Res>
    implements _$PlaybackStateCopyWith<$Res> {
  __$PlaybackStateCopyWithImpl(this._self, this._then);

  final _PlaybackState _self;
  final $Res Function(_PlaybackState) _then;

/// Create a copy of PlaybackState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? qualityLabel = freezed,Object? lineId = freezed,Object? recoveryAttempts = null,Object? lastFailure = freezed,}) {
  return _then(_PlaybackState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as PlaybackPhase,qualityLabel: freezed == qualityLabel ? _self.qualityLabel : qualityLabel // ignore: cast_nullable_to_non_nullable
as String?,lineId: freezed == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String?,recoveryAttempts: null == recoveryAttempts ? _self.recoveryAttempts : recoveryAttempts // ignore: cast_nullable_to_non_nullable
as int,lastFailure: freezed == lastFailure ? _self.lastFailure : lastFailure // ignore: cast_nullable_to_non_nullable
as PlaybackFailure?,
  ));
}

/// Create a copy of PlaybackState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackFailureCopyWith<$Res>? get lastFailure {
    if (_self.lastFailure == null) {
    return null;
  }

  return $PlaybackFailureCopyWith<$Res>(_self.lastFailure!, (value) {
    return _then(_self.copyWith(lastFailure: value));
  });
}
}

// dart format on
