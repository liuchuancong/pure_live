// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackFailure {

/// Human-readable detail.
 String get detail;
/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackFailureCopyWith<PlaybackFailure> get copyWith => _$PlaybackFailureCopyWithImpl<PlaybackFailure>(this as PlaybackFailure, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaybackFailure;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackFailure&&(identical(other.detail, _this.detail) || other.detail == _this.detail));
}


@override
int get hashCode {
  final _this = this as PlaybackFailure;
  return Object.hash(runtimeType,_this.detail);
}

@override
String toString() {
  final _this = this as PlaybackFailure;
  return 'PlaybackFailure(detail: ${_this.detail})';
}


}

/// @nodoc
abstract mixin class $PlaybackFailureCopyWith<$Res>  {
  factory $PlaybackFailureCopyWith(PlaybackFailure value, $Res Function(PlaybackFailure) _then) = _$PlaybackFailureCopyWithImpl;
@useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$PlaybackFailureCopyWithImpl<$Res>
    implements $PlaybackFailureCopyWith<$Res> {
  _$PlaybackFailureCopyWithImpl(this._self, this._then);

  final PlaybackFailure _self;
  final $Res Function(PlaybackFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? detail = null,}) {
  return _then(_self.copyWith(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaybackFailure].
extension PlaybackFailurePatterns on PlaybackFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( StreamUnavailableFailure value)?  streamUnavailable,TResult Function( NotLiveFailure value)?  notLive,TResult Function( NeedsLoginFailure value)?  needsLogin,TResult Function( RateLimitedFailure value)?  rateLimited,TResult Function( NetworkFailure value)?  network,TResult Function( EngineFailure value)?  engine,TResult Function( ApiChangedFailure value)?  apiChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case StreamUnavailableFailure() when streamUnavailable != null:
return streamUnavailable(_that);case NotLiveFailure() when notLive != null:
return notLive(_that);case NeedsLoginFailure() when needsLogin != null:
return needsLogin(_that);case RateLimitedFailure() when rateLimited != null:
return rateLimited(_that);case NetworkFailure() when network != null:
return network(_that);case EngineFailure() when engine != null:
return engine(_that);case ApiChangedFailure() when apiChanged != null:
return apiChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( StreamUnavailableFailure value)  streamUnavailable,required TResult Function( NotLiveFailure value)  notLive,required TResult Function( NeedsLoginFailure value)  needsLogin,required TResult Function( RateLimitedFailure value)  rateLimited,required TResult Function( NetworkFailure value)  network,required TResult Function( EngineFailure value)  engine,required TResult Function( ApiChangedFailure value)  apiChanged,}){
final _that = this;
switch (_that) {
case StreamUnavailableFailure():
return streamUnavailable(_that);case NotLiveFailure():
return notLive(_that);case NeedsLoginFailure():
return needsLogin(_that);case RateLimitedFailure():
return rateLimited(_that);case NetworkFailure():
return network(_that);case EngineFailure():
return engine(_that);case ApiChangedFailure():
return apiChanged(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( StreamUnavailableFailure value)?  streamUnavailable,TResult? Function( NotLiveFailure value)?  notLive,TResult? Function( NeedsLoginFailure value)?  needsLogin,TResult? Function( RateLimitedFailure value)?  rateLimited,TResult? Function( NetworkFailure value)?  network,TResult? Function( EngineFailure value)?  engine,TResult? Function( ApiChangedFailure value)?  apiChanged,}){
final _that = this;
switch (_that) {
case StreamUnavailableFailure() when streamUnavailable != null:
return streamUnavailable(_that);case NotLiveFailure() when notLive != null:
return notLive(_that);case NeedsLoginFailure() when needsLogin != null:
return needsLogin(_that);case RateLimitedFailure() when rateLimited != null:
return rateLimited(_that);case NetworkFailure() when network != null:
return network(_that);case EngineFailure() when engine != null:
return engine(_that);case ApiChangedFailure() when apiChanged != null:
return apiChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String detail)?  streamUnavailable,TResult Function( String detail)?  notLive,TResult Function( String detail)?  needsLogin,TResult Function( String detail)?  rateLimited,TResult Function( String detail)?  network,TResult Function( String detail,  Object? cause)?  engine,TResult Function( String detail)?  apiChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case StreamUnavailableFailure() when streamUnavailable != null:
return streamUnavailable(_that.detail);case NotLiveFailure() when notLive != null:
return notLive(_that.detail);case NeedsLoginFailure() when needsLogin != null:
return needsLogin(_that.detail);case RateLimitedFailure() when rateLimited != null:
return rateLimited(_that.detail);case NetworkFailure() when network != null:
return network(_that.detail);case EngineFailure() when engine != null:
return engine(_that.detail,_that.cause);case ApiChangedFailure() when apiChanged != null:
return apiChanged(_that.detail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String detail)  streamUnavailable,required TResult Function( String detail)  notLive,required TResult Function( String detail)  needsLogin,required TResult Function( String detail)  rateLimited,required TResult Function( String detail)  network,required TResult Function( String detail,  Object? cause)  engine,required TResult Function( String detail)  apiChanged,}) {final _that = this;
switch (_that) {
case StreamUnavailableFailure():
return streamUnavailable(_that.detail);case NotLiveFailure():
return notLive(_that.detail);case NeedsLoginFailure():
return needsLogin(_that.detail);case RateLimitedFailure():
return rateLimited(_that.detail);case NetworkFailure():
return network(_that.detail);case EngineFailure():
return engine(_that.detail,_that.cause);case ApiChangedFailure():
return apiChanged(_that.detail);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String detail)?  streamUnavailable,TResult? Function( String detail)?  notLive,TResult? Function( String detail)?  needsLogin,TResult? Function( String detail)?  rateLimited,TResult? Function( String detail)?  network,TResult? Function( String detail,  Object? cause)?  engine,TResult? Function( String detail)?  apiChanged,}) {final _that = this;
switch (_that) {
case StreamUnavailableFailure() when streamUnavailable != null:
return streamUnavailable(_that.detail);case NotLiveFailure() when notLive != null:
return notLive(_that.detail);case NeedsLoginFailure() when needsLogin != null:
return needsLogin(_that.detail);case RateLimitedFailure() when rateLimited != null:
return rateLimited(_that.detail);case NetworkFailure() when network != null:
return network(_that.detail);case EngineFailure() when engine != null:
return engine(_that.detail,_that.cause);case ApiChangedFailure() when apiChanged != null:
return apiChanged(_that.detail);case _:
  return null;

}
}

}

/// @nodoc


class StreamUnavailableFailure implements PlaybackFailure {
  const StreamUnavailableFailure({required this.detail});
  

/// Human-readable detail.
@override final  String detail;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreamUnavailableFailureCopyWith<StreamUnavailableFailure> get copyWith => _$StreamUnavailableFailureCopyWithImpl<StreamUnavailableFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StreamUnavailableFailure&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'PlaybackFailure.streamUnavailable(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $StreamUnavailableFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $StreamUnavailableFailureCopyWith(StreamUnavailableFailure value, $Res Function(StreamUnavailableFailure) _then) = _$StreamUnavailableFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$StreamUnavailableFailureCopyWithImpl<$Res>
    implements $StreamUnavailableFailureCopyWith<$Res> {
  _$StreamUnavailableFailureCopyWithImpl(this._self, this._then);

  final StreamUnavailableFailure _self;
  final $Res Function(StreamUnavailableFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(StreamUnavailableFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NotLiveFailure implements PlaybackFailure {
  const NotLiveFailure({required this.detail});
  

/// Human-readable detail.
@override final  String detail;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotLiveFailureCopyWith<NotLiveFailure> get copyWith => _$NotLiveFailureCopyWithImpl<NotLiveFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NotLiveFailure&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'PlaybackFailure.notLive(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $NotLiveFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $NotLiveFailureCopyWith(NotLiveFailure value, $Res Function(NotLiveFailure) _then) = _$NotLiveFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$NotLiveFailureCopyWithImpl<$Res>
    implements $NotLiveFailureCopyWith<$Res> {
  _$NotLiveFailureCopyWithImpl(this._self, this._then);

  final NotLiveFailure _self;
  final $Res Function(NotLiveFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(NotLiveFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NeedsLoginFailure implements PlaybackFailure {
  const NeedsLoginFailure({required this.detail});
  

/// Human-readable detail.
@override final  String detail;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NeedsLoginFailureCopyWith<NeedsLoginFailure> get copyWith => _$NeedsLoginFailureCopyWithImpl<NeedsLoginFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NeedsLoginFailure&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'PlaybackFailure.needsLogin(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $NeedsLoginFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $NeedsLoginFailureCopyWith(NeedsLoginFailure value, $Res Function(NeedsLoginFailure) _then) = _$NeedsLoginFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$NeedsLoginFailureCopyWithImpl<$Res>
    implements $NeedsLoginFailureCopyWith<$Res> {
  _$NeedsLoginFailureCopyWithImpl(this._self, this._then);

  final NeedsLoginFailure _self;
  final $Res Function(NeedsLoginFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(NeedsLoginFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RateLimitedFailure implements PlaybackFailure {
  const RateLimitedFailure({required this.detail});
  

/// Human-readable detail.
@override final  String detail;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RateLimitedFailureCopyWith<RateLimitedFailure> get copyWith => _$RateLimitedFailureCopyWithImpl<RateLimitedFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RateLimitedFailure&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'PlaybackFailure.rateLimited(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $RateLimitedFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $RateLimitedFailureCopyWith(RateLimitedFailure value, $Res Function(RateLimitedFailure) _then) = _$RateLimitedFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$RateLimitedFailureCopyWithImpl<$Res>
    implements $RateLimitedFailureCopyWith<$Res> {
  _$RateLimitedFailureCopyWithImpl(this._self, this._then);

  final RateLimitedFailure _self;
  final $Res Function(RateLimitedFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(RateLimitedFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NetworkFailure implements PlaybackFailure {
  const NetworkFailure({required this.detail});
  

/// Human-readable detail.
@override final  String detail;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkFailureCopyWith<NetworkFailure> get copyWith => _$NetworkFailureCopyWithImpl<NetworkFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkFailure&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'PlaybackFailure.network(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $NetworkFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $NetworkFailureCopyWith(NetworkFailure value, $Res Function(NetworkFailure) _then) = _$NetworkFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$NetworkFailureCopyWithImpl<$Res>
    implements $NetworkFailureCopyWith<$Res> {
  _$NetworkFailureCopyWithImpl(this._self, this._then);

  final NetworkFailure _self;
  final $Res Function(NetworkFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(NetworkFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class EngineFailure implements PlaybackFailure {
  const EngineFailure({required this.detail, this.cause});
  

/// Human-readable detail.
@override final  String detail;
/// The underlying error, when one is available.
 final  Object? cause;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EngineFailureCopyWith<EngineFailure> get copyWith => _$EngineFailureCopyWithImpl<EngineFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is EngineFailure&&(identical(other.detail, detail) || other.detail == detail)&&const DeepCollectionEquality().equals(other.cause, cause));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail,const DeepCollectionEquality().hash(cause));
}

@override
String toString() {
    return 'PlaybackFailure.engine(detail: $detail, cause: $cause)';
}


}

/// @nodoc
abstract mixin class $EngineFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $EngineFailureCopyWith(EngineFailure value, $Res Function(EngineFailure) _then) = _$EngineFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail, Object? cause
});




}
/// @nodoc
class _$EngineFailureCopyWithImpl<$Res>
    implements $EngineFailureCopyWith<$Res> {
  _$EngineFailureCopyWithImpl(this._self, this._then);

  final EngineFailure _self;
  final $Res Function(EngineFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,Object? cause = freezed,}) {
  return _then(EngineFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,
  ));
}


}

/// @nodoc


class ApiChangedFailure implements PlaybackFailure {
  const ApiChangedFailure({required this.detail});
  

/// Human-readable detail.
@override final  String detail;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiChangedFailureCopyWith<ApiChangedFailure> get copyWith => _$ApiChangedFailureCopyWithImpl<ApiChangedFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiChangedFailure&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,detail);
}

@override
String toString() {
    return 'PlaybackFailure.apiChanged(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $ApiChangedFailureCopyWith<$Res> implements $PlaybackFailureCopyWith<$Res> {
  factory $ApiChangedFailureCopyWith(ApiChangedFailure value, $Res Function(ApiChangedFailure) _then) = _$ApiChangedFailureCopyWithImpl;
@override @useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$ApiChangedFailureCopyWithImpl<$Res>
    implements $ApiChangedFailureCopyWith<$Res> {
  _$ApiChangedFailureCopyWithImpl(this._self, this._then);

  final ApiChangedFailure _self;
  final $Res Function(ApiChangedFailure) _then;

/// Create a copy of PlaybackFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(ApiChangedFailure(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
