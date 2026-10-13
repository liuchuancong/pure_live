// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlaybackEvent()';
}


}

/// @nodoc
class $PlaybackEventCopyWith<$Res>  {
$PlaybackEventCopyWith(PlaybackEvent _, $Res Function(PlaybackEvent) __);
}


/// Adds pattern-matching-related methods to [PlaybackEvent].
extension PlaybackEventPatterns on PlaybackEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlaybackStarted value)?  started,TResult Function( PlaybackFailed value)?  failed,TResult Function( PlaybackRecovered value)?  recovered,TResult Function( PlaybackRenewing value)?  renewing,TResult Function( PlaybackGaveUp value)?  gaveUp,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlaybackStarted() when started != null:
return started(_that);case PlaybackFailed() when failed != null:
return failed(_that);case PlaybackRecovered() when recovered != null:
return recovered(_that);case PlaybackRenewing() when renewing != null:
return renewing(_that);case PlaybackGaveUp() when gaveUp != null:
return gaveUp(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlaybackStarted value)  started,required TResult Function( PlaybackFailed value)  failed,required TResult Function( PlaybackRecovered value)  recovered,required TResult Function( PlaybackRenewing value)  renewing,required TResult Function( PlaybackGaveUp value)  gaveUp,}){
final _that = this;
switch (_that) {
case PlaybackStarted():
return started(_that);case PlaybackFailed():
return failed(_that);case PlaybackRecovered():
return recovered(_that);case PlaybackRenewing():
return renewing(_that);case PlaybackGaveUp():
return gaveUp(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlaybackStarted value)?  started,TResult? Function( PlaybackFailed value)?  failed,TResult? Function( PlaybackRecovered value)?  recovered,TResult? Function( PlaybackRenewing value)?  renewing,TResult? Function( PlaybackGaveUp value)?  gaveUp,}){
final _that = this;
switch (_that) {
case PlaybackStarted() when started != null:
return started(_that);case PlaybackFailed() when failed != null:
return failed(_that);case PlaybackRecovered() when recovered != null:
return recovered(_that);case PlaybackRenewing() when renewing != null:
return renewing(_that);case PlaybackGaveUp() when gaveUp != null:
return gaveUp(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String quality,  String? lineId)?  started,TResult Function( PlaybackFailure failure)?  failed,TResult Function( String quality,  int attempt)?  recovered,TResult Function( String quality)?  renewing,TResult Function( PlaybackFailure failure)?  gaveUp,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlaybackStarted() when started != null:
return started(_that.quality,_that.lineId);case PlaybackFailed() when failed != null:
return failed(_that.failure);case PlaybackRecovered() when recovered != null:
return recovered(_that.quality,_that.attempt);case PlaybackRenewing() when renewing != null:
return renewing(_that.quality);case PlaybackGaveUp() when gaveUp != null:
return gaveUp(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String quality,  String? lineId)  started,required TResult Function( PlaybackFailure failure)  failed,required TResult Function( String quality,  int attempt)  recovered,required TResult Function( String quality)  renewing,required TResult Function( PlaybackFailure failure)  gaveUp,}) {final _that = this;
switch (_that) {
case PlaybackStarted():
return started(_that.quality,_that.lineId);case PlaybackFailed():
return failed(_that.failure);case PlaybackRecovered():
return recovered(_that.quality,_that.attempt);case PlaybackRenewing():
return renewing(_that.quality);case PlaybackGaveUp():
return gaveUp(_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String quality,  String? lineId)?  started,TResult? Function( PlaybackFailure failure)?  failed,TResult? Function( String quality,  int attempt)?  recovered,TResult? Function( String quality)?  renewing,TResult? Function( PlaybackFailure failure)?  gaveUp,}) {final _that = this;
switch (_that) {
case PlaybackStarted() when started != null:
return started(_that.quality,_that.lineId);case PlaybackFailed() when failed != null:
return failed(_that.failure);case PlaybackRecovered() when recovered != null:
return recovered(_that.quality,_that.attempt);case PlaybackRenewing() when renewing != null:
return renewing(_that.quality);case PlaybackGaveUp() when gaveUp != null:
return gaveUp(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class PlaybackStarted implements PlaybackEvent {
  const PlaybackStarted({required this.quality, this.lineId});
  

/// The quality label.
 final  String quality;
/// The line id, when the line has one.
 final  String? lineId;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackStartedCopyWith<PlaybackStarted> get copyWith => _$PlaybackStartedCopyWithImpl<PlaybackStarted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackStarted&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.lineId, lineId) || other.lineId == lineId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,quality,lineId);
}

@override
String toString() {
    return 'PlaybackEvent.started(quality: $quality, lineId: $lineId)';
}


}

/// @nodoc
abstract mixin class $PlaybackStartedCopyWith<$Res> implements $PlaybackEventCopyWith<$Res> {
  factory $PlaybackStartedCopyWith(PlaybackStarted value, $Res Function(PlaybackStarted) _then) = _$PlaybackStartedCopyWithImpl;
@useResult
$Res call({
 String quality, String? lineId
});




}
/// @nodoc
class _$PlaybackStartedCopyWithImpl<$Res>
    implements $PlaybackStartedCopyWith<$Res> {
  _$PlaybackStartedCopyWithImpl(this._self, this._then);

  final PlaybackStarted _self;
  final $Res Function(PlaybackStarted) _then;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? quality = null,Object? lineId = freezed,}) {
  return _then(PlaybackStarted(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as String,lineId: freezed == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class PlaybackFailed implements PlaybackEvent {
  const PlaybackFailed({required this.failure});
  

/// The classified failure.
 final  PlaybackFailure failure;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackFailedCopyWith<PlaybackFailed> get copyWith => _$PlaybackFailedCopyWithImpl<PlaybackFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackFailed&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'PlaybackEvent.failed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PlaybackFailedCopyWith<$Res> implements $PlaybackEventCopyWith<$Res> {
  factory $PlaybackFailedCopyWith(PlaybackFailed value, $Res Function(PlaybackFailed) _then) = _$PlaybackFailedCopyWithImpl;
@useResult
$Res call({
 PlaybackFailure failure
});


$PlaybackFailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$PlaybackFailedCopyWithImpl<$Res>
    implements $PlaybackFailedCopyWith<$Res> {
  _$PlaybackFailedCopyWithImpl(this._self, this._then);

  final PlaybackFailed _self;
  final $Res Function(PlaybackFailed) _then;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(PlaybackFailed(
failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as PlaybackFailure,
  ));
}

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackFailureCopyWith<$Res> get failure {
  
  return $PlaybackFailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

/// @nodoc


class PlaybackRecovered implements PlaybackEvent {
  const PlaybackRecovered({required this.quality, required this.attempt});
  

/// The quality the ladder moved to.
 final  String quality;
/// The attempt number (1-based).
 final  int attempt;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackRecoveredCopyWith<PlaybackRecovered> get copyWith => _$PlaybackRecoveredCopyWithImpl<PlaybackRecovered>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackRecovered&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.attempt, attempt) || other.attempt == attempt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,quality,attempt);
}

@override
String toString() {
    return 'PlaybackEvent.recovered(quality: $quality, attempt: $attempt)';
}


}

/// @nodoc
abstract mixin class $PlaybackRecoveredCopyWith<$Res> implements $PlaybackEventCopyWith<$Res> {
  factory $PlaybackRecoveredCopyWith(PlaybackRecovered value, $Res Function(PlaybackRecovered) _then) = _$PlaybackRecoveredCopyWithImpl;
@useResult
$Res call({
 String quality, int attempt
});




}
/// @nodoc
class _$PlaybackRecoveredCopyWithImpl<$Res>
    implements $PlaybackRecoveredCopyWith<$Res> {
  _$PlaybackRecoveredCopyWithImpl(this._self, this._then);

  final PlaybackRecovered _self;
  final $Res Function(PlaybackRecovered) _then;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? quality = null,Object? attempt = null,}) {
  return _then(PlaybackRecovered(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as String,attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class PlaybackRenewing implements PlaybackEvent {
  const PlaybackRenewing({required this.quality});
  

/// The line being renewed.
 final  String quality;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackRenewingCopyWith<PlaybackRenewing> get copyWith => _$PlaybackRenewingCopyWithImpl<PlaybackRenewing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackRenewing&&(identical(other.quality, quality) || other.quality == quality));
}


@override
int get hashCode {
    return Object.hash(runtimeType,quality);
}

@override
String toString() {
    return 'PlaybackEvent.renewing(quality: $quality)';
}


}

/// @nodoc
abstract mixin class $PlaybackRenewingCopyWith<$Res> implements $PlaybackEventCopyWith<$Res> {
  factory $PlaybackRenewingCopyWith(PlaybackRenewing value, $Res Function(PlaybackRenewing) _then) = _$PlaybackRenewingCopyWithImpl;
@useResult
$Res call({
 String quality
});




}
/// @nodoc
class _$PlaybackRenewingCopyWithImpl<$Res>
    implements $PlaybackRenewingCopyWith<$Res> {
  _$PlaybackRenewingCopyWithImpl(this._self, this._then);

  final PlaybackRenewing _self;
  final $Res Function(PlaybackRenewing) _then;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? quality = null,}) {
  return _then(PlaybackRenewing(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PlaybackGaveUp implements PlaybackEvent {
  const PlaybackGaveUp({required this.failure});
  

/// Why.
 final  PlaybackFailure failure;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackGaveUpCopyWith<PlaybackGaveUp> get copyWith => _$PlaybackGaveUpCopyWithImpl<PlaybackGaveUp>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackGaveUp&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'PlaybackEvent.gaveUp(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PlaybackGaveUpCopyWith<$Res> implements $PlaybackEventCopyWith<$Res> {
  factory $PlaybackGaveUpCopyWith(PlaybackGaveUp value, $Res Function(PlaybackGaveUp) _then) = _$PlaybackGaveUpCopyWithImpl;
@useResult
$Res call({
 PlaybackFailure failure
});


$PlaybackFailureCopyWith<$Res> get failure;

}
/// @nodoc
class _$PlaybackGaveUpCopyWithImpl<$Res>
    implements $PlaybackGaveUpCopyWith<$Res> {
  _$PlaybackGaveUpCopyWithImpl(this._self, this._then);

  final PlaybackGaveUp _self;
  final $Res Function(PlaybackGaveUp) _then;

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(PlaybackGaveUp(
failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as PlaybackFailure,
  ));
}

/// Create a copy of PlaybackEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackFailureCopyWith<$Res> get failure {
  
  return $PlaybackFailureCopyWith<$Res>(_self.failure, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

// dart format on
