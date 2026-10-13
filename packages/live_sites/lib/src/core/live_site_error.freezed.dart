// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_site_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveSiteError {

 String get siteId; String get message;
/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteErrorCopyWith<LiveSiteError> get copyWith => _$LiveSiteErrorCopyWithImpl<LiveSiteError>(this as LiveSiteError, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveSiteError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteError&&(identical(other.siteId, _this.siteId) || other.siteId == _this.siteId)&&(identical(other.message, _this.message) || other.message == _this.message));
}


@override
int get hashCode {
  final _this = this as LiveSiteError;
  return Object.hash(runtimeType,_this.siteId,_this.message);
}

@override
String toString() {
  final _this = this as LiveSiteError;
  return 'LiveSiteError(siteId: ${_this.siteId}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $LiveSiteErrorCopyWith<$Res>  {
  factory $LiveSiteErrorCopyWith(LiveSiteError value, $Res Function(LiveSiteError) _then) = _$LiveSiteErrorCopyWithImpl;
@useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteErrorCopyWithImpl<$Res>
    implements $LiveSiteErrorCopyWith<$Res> {
  _$LiveSiteErrorCopyWithImpl(this._self, this._then);

  final LiveSiteError _self;
  final $Res Function(LiveSiteError) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(_self.copyWith(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveSiteError].
extension LiveSiteErrorPatterns on LiveSiteError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LiveSiteNotFound value)?  notFound,TResult Function( LiveSiteUnsupported value)?  unsupported,TResult Function( LiveSiteNetworkError value)?  network,TResult Function( LiveSiteParseError value)?  parse,TResult Function( LiveSiteAuthenticationError value)?  authentication,TResult Function( LiveSiteRateLimitError value)?  rateLimit,TResult Function( LiveSiteContentUnavailable value)?  contentUnavailable,TResult Function( LiveSiteInvalidArgument value)?  invalidArgument,TResult Function( LiveSiteUnexpectedError value)?  unexpected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LiveSiteNotFound() when notFound != null:
return notFound(_that);case LiveSiteUnsupported() when unsupported != null:
return unsupported(_that);case LiveSiteNetworkError() when network != null:
return network(_that);case LiveSiteParseError() when parse != null:
return parse(_that);case LiveSiteAuthenticationError() when authentication != null:
return authentication(_that);case LiveSiteRateLimitError() when rateLimit != null:
return rateLimit(_that);case LiveSiteContentUnavailable() when contentUnavailable != null:
return contentUnavailable(_that);case LiveSiteInvalidArgument() when invalidArgument != null:
return invalidArgument(_that);case LiveSiteUnexpectedError() when unexpected != null:
return unexpected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LiveSiteNotFound value)  notFound,required TResult Function( LiveSiteUnsupported value)  unsupported,required TResult Function( LiveSiteNetworkError value)  network,required TResult Function( LiveSiteParseError value)  parse,required TResult Function( LiveSiteAuthenticationError value)  authentication,required TResult Function( LiveSiteRateLimitError value)  rateLimit,required TResult Function( LiveSiteContentUnavailable value)  contentUnavailable,required TResult Function( LiveSiteInvalidArgument value)  invalidArgument,required TResult Function( LiveSiteUnexpectedError value)  unexpected,}){
final _that = this;
switch (_that) {
case LiveSiteNotFound():
return notFound(_that);case LiveSiteUnsupported():
return unsupported(_that);case LiveSiteNetworkError():
return network(_that);case LiveSiteParseError():
return parse(_that);case LiveSiteAuthenticationError():
return authentication(_that);case LiveSiteRateLimitError():
return rateLimit(_that);case LiveSiteContentUnavailable():
return contentUnavailable(_that);case LiveSiteInvalidArgument():
return invalidArgument(_that);case LiveSiteUnexpectedError():
return unexpected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LiveSiteNotFound value)?  notFound,TResult? Function( LiveSiteUnsupported value)?  unsupported,TResult? Function( LiveSiteNetworkError value)?  network,TResult? Function( LiveSiteParseError value)?  parse,TResult? Function( LiveSiteAuthenticationError value)?  authentication,TResult? Function( LiveSiteRateLimitError value)?  rateLimit,TResult? Function( LiveSiteContentUnavailable value)?  contentUnavailable,TResult? Function( LiveSiteInvalidArgument value)?  invalidArgument,TResult? Function( LiveSiteUnexpectedError value)?  unexpected,}){
final _that = this;
switch (_that) {
case LiveSiteNotFound() when notFound != null:
return notFound(_that);case LiveSiteUnsupported() when unsupported != null:
return unsupported(_that);case LiveSiteNetworkError() when network != null:
return network(_that);case LiveSiteParseError() when parse != null:
return parse(_that);case LiveSiteAuthenticationError() when authentication != null:
return authentication(_that);case LiveSiteRateLimitError() when rateLimit != null:
return rateLimit(_that);case LiveSiteContentUnavailable() when contentUnavailable != null:
return contentUnavailable(_that);case LiveSiteInvalidArgument() when invalidArgument != null:
return invalidArgument(_that);case LiveSiteUnexpectedError() when unexpected != null:
return unexpected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String siteId,  String message)?  notFound,TResult Function( String siteId,  String message)?  unsupported,TResult Function( String siteId,  String message,  Object? cause)?  network,TResult Function( String siteId,  String message,  Object? cause)?  parse,TResult Function( String siteId,  String message)?  authentication,TResult Function( String siteId,  String message)?  rateLimit,TResult Function( String siteId,  String message)?  contentUnavailable,TResult Function( String siteId,  String message)?  invalidArgument,TResult Function( String siteId,  String message,  Object? cause)?  unexpected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LiveSiteNotFound() when notFound != null:
return notFound(_that.siteId,_that.message);case LiveSiteUnsupported() when unsupported != null:
return unsupported(_that.siteId,_that.message);case LiveSiteNetworkError() when network != null:
return network(_that.siteId,_that.message,_that.cause);case LiveSiteParseError() when parse != null:
return parse(_that.siteId,_that.message,_that.cause);case LiveSiteAuthenticationError() when authentication != null:
return authentication(_that.siteId,_that.message);case LiveSiteRateLimitError() when rateLimit != null:
return rateLimit(_that.siteId,_that.message);case LiveSiteContentUnavailable() when contentUnavailable != null:
return contentUnavailable(_that.siteId,_that.message);case LiveSiteInvalidArgument() when invalidArgument != null:
return invalidArgument(_that.siteId,_that.message);case LiveSiteUnexpectedError() when unexpected != null:
return unexpected(_that.siteId,_that.message,_that.cause);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String siteId,  String message)  notFound,required TResult Function( String siteId,  String message)  unsupported,required TResult Function( String siteId,  String message,  Object? cause)  network,required TResult Function( String siteId,  String message,  Object? cause)  parse,required TResult Function( String siteId,  String message)  authentication,required TResult Function( String siteId,  String message)  rateLimit,required TResult Function( String siteId,  String message)  contentUnavailable,required TResult Function( String siteId,  String message)  invalidArgument,required TResult Function( String siteId,  String message,  Object? cause)  unexpected,}) {final _that = this;
switch (_that) {
case LiveSiteNotFound():
return notFound(_that.siteId,_that.message);case LiveSiteUnsupported():
return unsupported(_that.siteId,_that.message);case LiveSiteNetworkError():
return network(_that.siteId,_that.message,_that.cause);case LiveSiteParseError():
return parse(_that.siteId,_that.message,_that.cause);case LiveSiteAuthenticationError():
return authentication(_that.siteId,_that.message);case LiveSiteRateLimitError():
return rateLimit(_that.siteId,_that.message);case LiveSiteContentUnavailable():
return contentUnavailable(_that.siteId,_that.message);case LiveSiteInvalidArgument():
return invalidArgument(_that.siteId,_that.message);case LiveSiteUnexpectedError():
return unexpected(_that.siteId,_that.message,_that.cause);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String siteId,  String message)?  notFound,TResult? Function( String siteId,  String message)?  unsupported,TResult? Function( String siteId,  String message,  Object? cause)?  network,TResult? Function( String siteId,  String message,  Object? cause)?  parse,TResult? Function( String siteId,  String message)?  authentication,TResult? Function( String siteId,  String message)?  rateLimit,TResult? Function( String siteId,  String message)?  contentUnavailable,TResult? Function( String siteId,  String message)?  invalidArgument,TResult? Function( String siteId,  String message,  Object? cause)?  unexpected,}) {final _that = this;
switch (_that) {
case LiveSiteNotFound() when notFound != null:
return notFound(_that.siteId,_that.message);case LiveSiteUnsupported() when unsupported != null:
return unsupported(_that.siteId,_that.message);case LiveSiteNetworkError() when network != null:
return network(_that.siteId,_that.message,_that.cause);case LiveSiteParseError() when parse != null:
return parse(_that.siteId,_that.message,_that.cause);case LiveSiteAuthenticationError() when authentication != null:
return authentication(_that.siteId,_that.message);case LiveSiteRateLimitError() when rateLimit != null:
return rateLimit(_that.siteId,_that.message);case LiveSiteContentUnavailable() when contentUnavailable != null:
return contentUnavailable(_that.siteId,_that.message);case LiveSiteInvalidArgument() when invalidArgument != null:
return invalidArgument(_that.siteId,_that.message);case LiveSiteUnexpectedError() when unexpected != null:
return unexpected(_that.siteId,_that.message,_that.cause);case _:
  return null;

}
}

}

/// @nodoc


class LiveSiteNotFound implements LiveSiteError {
  const LiveSiteNotFound({required this.siteId, required this.message});
  

@override final  String siteId;
@override final  String message;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteNotFoundCopyWith<LiveSiteNotFound> get copyWith => _$LiveSiteNotFoundCopyWithImpl<LiveSiteNotFound>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteNotFound&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message);
}

@override
String toString() {
    return 'LiveSiteError.notFound(siteId: $siteId, message: $message)';
}


}

/// @nodoc
abstract mixin class $LiveSiteNotFoundCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteNotFoundCopyWith(LiveSiteNotFound value, $Res Function(LiveSiteNotFound) _then) = _$LiveSiteNotFoundCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteNotFoundCopyWithImpl<$Res>
    implements $LiveSiteNotFoundCopyWith<$Res> {
  _$LiveSiteNotFoundCopyWithImpl(this._self, this._then);

  final LiveSiteNotFound _self;
  final $Res Function(LiveSiteNotFound) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(LiveSiteNotFound(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LiveSiteUnsupported implements LiveSiteError {
  const LiveSiteUnsupported({required this.siteId, required this.message});
  

@override final  String siteId;
@override final  String message;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteUnsupportedCopyWith<LiveSiteUnsupported> get copyWith => _$LiveSiteUnsupportedCopyWithImpl<LiveSiteUnsupported>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteUnsupported&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message);
}

@override
String toString() {
    return 'LiveSiteError.unsupported(siteId: $siteId, message: $message)';
}


}

/// @nodoc
abstract mixin class $LiveSiteUnsupportedCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteUnsupportedCopyWith(LiveSiteUnsupported value, $Res Function(LiveSiteUnsupported) _then) = _$LiveSiteUnsupportedCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteUnsupportedCopyWithImpl<$Res>
    implements $LiveSiteUnsupportedCopyWith<$Res> {
  _$LiveSiteUnsupportedCopyWithImpl(this._self, this._then);

  final LiveSiteUnsupported _self;
  final $Res Function(LiveSiteUnsupported) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(LiveSiteUnsupported(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LiveSiteNetworkError implements LiveSiteError {
  const LiveSiteNetworkError({required this.siteId, required this.message, this.cause});
  

@override final  String siteId;
@override final  String message;
 final  Object? cause;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteNetworkErrorCopyWith<LiveSiteNetworkError> get copyWith => _$LiveSiteNetworkErrorCopyWithImpl<LiveSiteNetworkError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteNetworkError&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.cause, cause));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message,const DeepCollectionEquality().hash(cause));
}

@override
String toString() {
    return 'LiveSiteError.network(siteId: $siteId, message: $message, cause: $cause)';
}


}

/// @nodoc
abstract mixin class $LiveSiteNetworkErrorCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteNetworkErrorCopyWith(LiveSiteNetworkError value, $Res Function(LiveSiteNetworkError) _then) = _$LiveSiteNetworkErrorCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message, Object? cause
});




}
/// @nodoc
class _$LiveSiteNetworkErrorCopyWithImpl<$Res>
    implements $LiveSiteNetworkErrorCopyWith<$Res> {
  _$LiveSiteNetworkErrorCopyWithImpl(this._self, this._then);

  final LiveSiteNetworkError _self;
  final $Res Function(LiveSiteNetworkError) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,Object? cause = freezed,}) {
  return _then(LiveSiteNetworkError(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,
  ));
}


}

/// @nodoc


class LiveSiteParseError implements LiveSiteError {
  const LiveSiteParseError({required this.siteId, required this.message, this.cause});
  

@override final  String siteId;
@override final  String message;
 final  Object? cause;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteParseErrorCopyWith<LiveSiteParseError> get copyWith => _$LiveSiteParseErrorCopyWithImpl<LiveSiteParseError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteParseError&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.cause, cause));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message,const DeepCollectionEquality().hash(cause));
}

@override
String toString() {
    return 'LiveSiteError.parse(siteId: $siteId, message: $message, cause: $cause)';
}


}

/// @nodoc
abstract mixin class $LiveSiteParseErrorCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteParseErrorCopyWith(LiveSiteParseError value, $Res Function(LiveSiteParseError) _then) = _$LiveSiteParseErrorCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message, Object? cause
});




}
/// @nodoc
class _$LiveSiteParseErrorCopyWithImpl<$Res>
    implements $LiveSiteParseErrorCopyWith<$Res> {
  _$LiveSiteParseErrorCopyWithImpl(this._self, this._then);

  final LiveSiteParseError _self;
  final $Res Function(LiveSiteParseError) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,Object? cause = freezed,}) {
  return _then(LiveSiteParseError(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,
  ));
}


}

/// @nodoc


class LiveSiteAuthenticationError implements LiveSiteError {
  const LiveSiteAuthenticationError({required this.siteId, required this.message});
  

@override final  String siteId;
@override final  String message;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteAuthenticationErrorCopyWith<LiveSiteAuthenticationError> get copyWith => _$LiveSiteAuthenticationErrorCopyWithImpl<LiveSiteAuthenticationError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteAuthenticationError&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message);
}

@override
String toString() {
    return 'LiveSiteError.authentication(siteId: $siteId, message: $message)';
}


}

/// @nodoc
abstract mixin class $LiveSiteAuthenticationErrorCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteAuthenticationErrorCopyWith(LiveSiteAuthenticationError value, $Res Function(LiveSiteAuthenticationError) _then) = _$LiveSiteAuthenticationErrorCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteAuthenticationErrorCopyWithImpl<$Res>
    implements $LiveSiteAuthenticationErrorCopyWith<$Res> {
  _$LiveSiteAuthenticationErrorCopyWithImpl(this._self, this._then);

  final LiveSiteAuthenticationError _self;
  final $Res Function(LiveSiteAuthenticationError) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(LiveSiteAuthenticationError(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LiveSiteRateLimitError implements LiveSiteError {
  const LiveSiteRateLimitError({required this.siteId, required this.message});
  

@override final  String siteId;
@override final  String message;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteRateLimitErrorCopyWith<LiveSiteRateLimitError> get copyWith => _$LiveSiteRateLimitErrorCopyWithImpl<LiveSiteRateLimitError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteRateLimitError&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message);
}

@override
String toString() {
    return 'LiveSiteError.rateLimit(siteId: $siteId, message: $message)';
}


}

/// @nodoc
abstract mixin class $LiveSiteRateLimitErrorCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteRateLimitErrorCopyWith(LiveSiteRateLimitError value, $Res Function(LiveSiteRateLimitError) _then) = _$LiveSiteRateLimitErrorCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteRateLimitErrorCopyWithImpl<$Res>
    implements $LiveSiteRateLimitErrorCopyWith<$Res> {
  _$LiveSiteRateLimitErrorCopyWithImpl(this._self, this._then);

  final LiveSiteRateLimitError _self;
  final $Res Function(LiveSiteRateLimitError) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(LiveSiteRateLimitError(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LiveSiteContentUnavailable implements LiveSiteError {
  const LiveSiteContentUnavailable({required this.siteId, required this.message});
  

@override final  String siteId;
@override final  String message;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteContentUnavailableCopyWith<LiveSiteContentUnavailable> get copyWith => _$LiveSiteContentUnavailableCopyWithImpl<LiveSiteContentUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteContentUnavailable&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message);
}

@override
String toString() {
    return 'LiveSiteError.contentUnavailable(siteId: $siteId, message: $message)';
}


}

/// @nodoc
abstract mixin class $LiveSiteContentUnavailableCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteContentUnavailableCopyWith(LiveSiteContentUnavailable value, $Res Function(LiveSiteContentUnavailable) _then) = _$LiveSiteContentUnavailableCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteContentUnavailableCopyWithImpl<$Res>
    implements $LiveSiteContentUnavailableCopyWith<$Res> {
  _$LiveSiteContentUnavailableCopyWithImpl(this._self, this._then);

  final LiveSiteContentUnavailable _self;
  final $Res Function(LiveSiteContentUnavailable) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(LiveSiteContentUnavailable(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LiveSiteInvalidArgument implements LiveSiteError {
  const LiveSiteInvalidArgument({required this.siteId, required this.message});
  

@override final  String siteId;
@override final  String message;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteInvalidArgumentCopyWith<LiveSiteInvalidArgument> get copyWith => _$LiveSiteInvalidArgumentCopyWithImpl<LiveSiteInvalidArgument>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteInvalidArgument&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message);
}

@override
String toString() {
    return 'LiveSiteError.invalidArgument(siteId: $siteId, message: $message)';
}


}

/// @nodoc
abstract mixin class $LiveSiteInvalidArgumentCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteInvalidArgumentCopyWith(LiveSiteInvalidArgument value, $Res Function(LiveSiteInvalidArgument) _then) = _$LiveSiteInvalidArgumentCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message
});




}
/// @nodoc
class _$LiveSiteInvalidArgumentCopyWithImpl<$Res>
    implements $LiveSiteInvalidArgumentCopyWith<$Res> {
  _$LiveSiteInvalidArgumentCopyWithImpl(this._self, this._then);

  final LiveSiteInvalidArgument _self;
  final $Res Function(LiveSiteInvalidArgument) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,}) {
  return _then(LiveSiteInvalidArgument(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LiveSiteUnexpectedError implements LiveSiteError {
  const LiveSiteUnexpectedError({required this.siteId, required this.message, this.cause});
  

@override final  String siteId;
@override final  String message;
 final  Object? cause;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSiteUnexpectedErrorCopyWith<LiveSiteUnexpectedError> get copyWith => _$LiveSiteUnexpectedErrorCopyWithImpl<LiveSiteUnexpectedError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSiteUnexpectedError&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.cause, cause));
}


@override
int get hashCode {
    return Object.hash(runtimeType,siteId,message,const DeepCollectionEquality().hash(cause));
}

@override
String toString() {
    return 'LiveSiteError.unexpected(siteId: $siteId, message: $message, cause: $cause)';
}


}

/// @nodoc
abstract mixin class $LiveSiteUnexpectedErrorCopyWith<$Res> implements $LiveSiteErrorCopyWith<$Res> {
  factory $LiveSiteUnexpectedErrorCopyWith(LiveSiteUnexpectedError value, $Res Function(LiveSiteUnexpectedError) _then) = _$LiveSiteUnexpectedErrorCopyWithImpl;
@override @useResult
$Res call({
 String siteId, String message, Object? cause
});




}
/// @nodoc
class _$LiveSiteUnexpectedErrorCopyWithImpl<$Res>
    implements $LiveSiteUnexpectedErrorCopyWith<$Res> {
  _$LiveSiteUnexpectedErrorCopyWithImpl(this._self, this._then);

  final LiveSiteUnexpectedError _self;
  final $Res Function(LiveSiteUnexpectedError) _then;

/// Create a copy of LiveSiteError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteId = null,Object? message = null,Object? cause = freezed,}) {
  return _then(LiveSiteUnexpectedError(
siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,
  ));
}


}

// dart format on
