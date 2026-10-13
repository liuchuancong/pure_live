// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_local.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomLocal {

@EpochMillisConverter() DateTime? get lastWatchedAt; List<String> get tagIds; int? get watchDurationMs;
/// Create a copy of RoomLocal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomLocalCopyWith<RoomLocal> get copyWith => _$RoomLocalCopyWithImpl<RoomLocal>(this as RoomLocal, _$identity);

  /// Serializes this RoomLocal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomLocal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomLocal&&(identical(other.lastWatchedAt, _this.lastWatchedAt) || other.lastWatchedAt == _this.lastWatchedAt)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&(identical(other.watchDurationMs, _this.watchDurationMs) || other.watchDurationMs == _this.watchDurationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomLocal;
  return Object.hash(runtimeType,_this.lastWatchedAt,const DeepCollectionEquality().hash(_this.tagIds),_this.watchDurationMs);
}

@override
String toString() {
  final _this = this as RoomLocal;
  return 'RoomLocal(lastWatchedAt: ${_this.lastWatchedAt}, tagIds: ${_this.tagIds}, watchDurationMs: ${_this.watchDurationMs})';
}


}

/// @nodoc
abstract mixin class $RoomLocalCopyWith<$Res>  {
  factory $RoomLocalCopyWith(RoomLocal value, $Res Function(RoomLocal) _then) = _$RoomLocalCopyWithImpl;
@useResult
$Res call({
@EpochMillisConverter() DateTime? lastWatchedAt, List<String> tagIds, int? watchDurationMs
});




}
/// @nodoc
class _$RoomLocalCopyWithImpl<$Res>
    implements $RoomLocalCopyWith<$Res> {
  _$RoomLocalCopyWithImpl(this._self, this._then);

  final RoomLocal _self;
  final $Res Function(RoomLocal) _then;

/// Create a copy of RoomLocal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastWatchedAt = freezed,Object? tagIds = null,Object? watchDurationMs = freezed,}) {
  return _then(RoomLocal(
lastWatchedAt: freezed == lastWatchedAt ? _self.lastWatchedAt : lastWatchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,watchDurationMs: freezed == watchDurationMs ? _self.watchDurationMs : watchDurationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomLocal].
extension RoomLocalPatterns on RoomLocal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomLocal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomLocal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomLocal value)  $default,){
final _that = this;
switch (_that) {
case _RoomLocal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomLocal value)?  $default,){
final _that = this;
switch (_that) {
case _RoomLocal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@EpochMillisConverter()  DateTime? lastWatchedAt,  List<String> tagIds,  int? watchDurationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomLocal() when $default != null:
return $default(_that.lastWatchedAt,_that.tagIds,_that.watchDurationMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@EpochMillisConverter()  DateTime? lastWatchedAt,  List<String> tagIds,  int? watchDurationMs)  $default,) {final _that = this;
switch (_that) {
case _RoomLocal():
return $default(_that.lastWatchedAt,_that.tagIds,_that.watchDurationMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@EpochMillisConverter()  DateTime? lastWatchedAt,  List<String> tagIds,  int? watchDurationMs)?  $default,) {final _that = this;
switch (_that) {
case _RoomLocal() when $default != null:
return $default(_that.lastWatchedAt,_that.tagIds,_that.watchDurationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomLocal implements RoomLocal {
  const _RoomLocal({@EpochMillisConverter() this.lastWatchedAt,  List<String> tagIds = const [], this.watchDurationMs}): _tagIds = tagIds;
  factory _RoomLocal.fromJson(Map<String, dynamic> json) => _$RoomLocalFromJson(json);

@override@EpochMillisConverter() final  DateTime? lastWatchedAt;
 final  List<String> _tagIds;
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

@override final  int? watchDurationMs;

/// Create a copy of RoomLocal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomLocalCopyWith<_RoomLocal> get copyWith => __$RoomLocalCopyWithImpl<_RoomLocal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomLocalToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomLocal&&(identical(other.lastWatchedAt, lastWatchedAt) || other.lastWatchedAt == lastWatchedAt)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&(identical(other.watchDurationMs, watchDurationMs) || other.watchDurationMs == watchDurationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,lastWatchedAt,const DeepCollectionEquality().hash(_tagIds),watchDurationMs);
}

@override
String toString() {
    return 'RoomLocal(lastWatchedAt: $lastWatchedAt, tagIds: $tagIds, watchDurationMs: $watchDurationMs)';
}


}

/// @nodoc
abstract mixin class _$RoomLocalCopyWith<$Res> implements $RoomLocalCopyWith<$Res> {
  factory _$RoomLocalCopyWith(_RoomLocal value, $Res Function(_RoomLocal) _then) = __$RoomLocalCopyWithImpl;
@override @useResult
$Res call({
@EpochMillisConverter() DateTime? lastWatchedAt, List<String> tagIds, int? watchDurationMs
});




}
/// @nodoc
class __$RoomLocalCopyWithImpl<$Res>
    implements _$RoomLocalCopyWith<$Res> {
  __$RoomLocalCopyWithImpl(this._self, this._then);

  final _RoomLocal _self;
  final $Res Function(_RoomLocal) _then;

/// Create a copy of RoomLocal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastWatchedAt = freezed,Object? tagIds = null,Object? watchDurationMs = freezed,}) {
  return _then(_RoomLocal(
lastWatchedAt: freezed == lastWatchedAt ? _self.lastWatchedAt : lastWatchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,watchDurationMs: freezed == watchDurationMs ? _self.watchDurationMs : watchDurationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
