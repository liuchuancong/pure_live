// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_retraction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveRetraction {

 String? get userId; String? get messageId; bool get all;
/// Create a copy of LiveRetraction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRetractionCopyWith<LiveRetraction> get copyWith => _$LiveRetractionCopyWithImpl<LiveRetraction>(this as LiveRetraction, _$identity);

  /// Serializes this LiveRetraction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRetraction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRetraction&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.all, _this.all) || other.all == _this.all));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRetraction;
  return Object.hash(runtimeType,_this.userId,_this.messageId,_this.all);
}

@override
String toString() {
  final _this = this as LiveRetraction;
  return 'LiveRetraction(userId: ${_this.userId}, messageId: ${_this.messageId}, all: ${_this.all})';
}


}

/// @nodoc
abstract mixin class $LiveRetractionCopyWith<$Res>  {
  factory $LiveRetractionCopyWith(LiveRetraction value, $Res Function(LiveRetraction) _then) = _$LiveRetractionCopyWithImpl;
@useResult
$Res call({
 String? userId, String? messageId, bool all
});




}
/// @nodoc
class _$LiveRetractionCopyWithImpl<$Res>
    implements $LiveRetractionCopyWith<$Res> {
  _$LiveRetractionCopyWithImpl(this._self, this._then);

  final LiveRetraction _self;
  final $Res Function(LiveRetraction) _then;

/// Create a copy of LiveRetraction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = freezed,Object? messageId = freezed,Object? all = null,}) {
  return _then(LiveRetraction(
userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveRetraction].
extension LiveRetractionPatterns on LiveRetraction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRetraction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRetraction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRetraction value)  $default,){
final _that = this;
switch (_that) {
case _LiveRetraction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRetraction value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRetraction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? userId,  String? messageId,  bool all)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRetraction() when $default != null:
return $default(_that.userId,_that.messageId,_that.all);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? userId,  String? messageId,  bool all)  $default,) {final _that = this;
switch (_that) {
case _LiveRetraction():
return $default(_that.userId,_that.messageId,_that.all);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? userId,  String? messageId,  bool all)?  $default,) {final _that = this;
switch (_that) {
case _LiveRetraction() when $default != null:
return $default(_that.userId,_that.messageId,_that.all);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRetraction extends LiveRetraction {
  const _LiveRetraction({this.userId, this.messageId, this.all = false}): super._();
  factory _LiveRetraction.fromJson(Map<String, dynamic> json) => _$LiveRetractionFromJson(json);

@override final  String? userId;
@override final  String? messageId;
@override@JsonKey() final  bool all;

/// Create a copy of LiveRetraction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRetractionCopyWith<_LiveRetraction> get copyWith => __$LiveRetractionCopyWithImpl<_LiveRetraction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRetractionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRetraction&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.all, all) || other.all == all));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,userId,messageId,all);
}

@override
String toString() {
    return 'LiveRetraction(userId: $userId, messageId: $messageId, all: $all)';
}


}

/// @nodoc
abstract mixin class _$LiveRetractionCopyWith<$Res> implements $LiveRetractionCopyWith<$Res> {
  factory _$LiveRetractionCopyWith(_LiveRetraction value, $Res Function(_LiveRetraction) _then) = __$LiveRetractionCopyWithImpl;
@override @useResult
$Res call({
 String? userId, String? messageId, bool all
});




}
/// @nodoc
class __$LiveRetractionCopyWithImpl<$Res>
    implements _$LiveRetractionCopyWith<$Res> {
  __$LiveRetractionCopyWithImpl(this._self, this._then);

  final _LiveRetraction _self;
  final $Res Function(_LiveRetraction) _then;

/// Create a copy of LiveRetraction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = freezed,Object? messageId = freezed,Object? all = null,}) {
  return _then(_LiveRetraction(
userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
