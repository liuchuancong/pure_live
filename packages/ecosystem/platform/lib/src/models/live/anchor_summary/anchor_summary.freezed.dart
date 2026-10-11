// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'anchor_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnchorSummary {

/// The anchor as content: following someone is a ref, and every other column here is display.
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef get ref;@JsonKey(fromJson: _name) String get name;@JsonKey(fromJson: _text, includeIfNull: false) String? get avatar;/// Follower count as the platform wrote it; null means it did not say, which is not zero.
@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? get fans;/// The room they are in right now, when the platform knows. This is what makes the row tappable: an anchor
/// without a live room opens a profile, not a player.
@JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false) ContentRef? get currentRoom;@JsonKey(fromJson: _text, includeIfNull: false) String? get description;@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get extra;
/// Create a copy of AnchorSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnchorSummaryCopyWith<AnchorSummary> get copyWith => _$AnchorSummaryCopyWithImpl<AnchorSummary>(this as AnchorSummary, _$identity);

  /// Serializes this AnchorSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AnchorSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnchorSummary&&(identical(other.ref, _this.ref) || other.ref == _this.ref)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.fans, _this.fans) || other.fans == _this.fans)&&(identical(other.currentRoom, _this.currentRoom) || other.currentRoom == _this.currentRoom)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.extra, _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AnchorSummary;
  return Object.hash(runtimeType,_this.ref,_this.name,_this.avatar,_this.fans,_this.currentRoom,_this.description,const DeepCollectionEquality().hash(_this.extra));
}



}

/// @nodoc
abstract mixin class $AnchorSummaryCopyWith<$Res>  {
  factory $AnchorSummaryCopyWith(AnchorSummary value, $Res Function(AnchorSummary) _then) = _$AnchorSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef ref,@JsonKey(fromJson: _name) String name,@JsonKey(fromJson: _text, includeIfNull: false) String? avatar,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? fans,@JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false) ContentRef? currentRoom,@JsonKey(fromJson: _text, includeIfNull: false) String? description,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});




}
/// @nodoc
class _$AnchorSummaryCopyWithImpl<$Res>
    implements $AnchorSummaryCopyWith<$Res> {
  _$AnchorSummaryCopyWithImpl(this._self, this._then);

  final AnchorSummary _self;
  final $Res Function(AnchorSummary) _then;

/// Create a copy of AnchorSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? name = null,Object? avatar = freezed,Object? fans = freezed,Object? currentRoom = freezed,Object? description = freezed,Object? extra = null,}) {
  return _then(AnchorSummary(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,fans: freezed == fans ? _self.fans : fans // ignore: cast_nullable_to_non_nullable
as int?,currentRoom: freezed == currentRoom ? _self.currentRoom : currentRoom // ignore: cast_nullable_to_non_nullable
as ContentRef?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [AnchorSummary].
extension AnchorSummaryPatterns on AnchorSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnchorSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnchorSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnchorSummary value)  $default,){
final _that = this;
switch (_that) {
case _AnchorSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnchorSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AnchorSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _name)  String name, @JsonKey(fromJson: _text, includeIfNull: false)  String? avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? fans, @JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false)  ContentRef? currentRoom, @JsonKey(fromJson: _text, includeIfNull: false)  String? description, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnchorSummary() when $default != null:
return $default(_that.ref,_that.name,_that.avatar,_that.fans,_that.currentRoom,_that.description,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _name)  String name, @JsonKey(fromJson: _text, includeIfNull: false)  String? avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? fans, @JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false)  ContentRef? currentRoom, @JsonKey(fromJson: _text, includeIfNull: false)  String? description, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)  $default,) {final _that = this;
switch (_that) {
case _AnchorSummary():
return $default(_that.ref,_that.name,_that.avatar,_that.fans,_that.currentRoom,_that.description,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: refFromJson, toJson: refToJson)  ContentRef ref, @JsonKey(fromJson: _name)  String name, @JsonKey(fromJson: _text, includeIfNull: false)  String? avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false)  int? fans, @JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false)  ContentRef? currentRoom, @JsonKey(fromJson: _text, includeIfNull: false)  String? description, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra)?  $default,) {final _that = this;
switch (_that) {
case _AnchorSummary() when $default != null:
return $default(_that.ref,_that.name,_that.avatar,_that.fans,_that.currentRoom,_that.description,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnchorSummary extends AnchorSummary {
  const _AnchorSummary({@JsonKey(fromJson: refFromJson, toJson: refToJson) required this.ref, @JsonKey(fromJson: _name) required this.name, @JsonKey(fromJson: _text, includeIfNull: false) this.avatar, @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) this.fans, @JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false) this.currentRoom, @JsonKey(fromJson: _text, includeIfNull: false) this.description, @JsonKey(fromJson: _map, toJson: _mapOut)  Map<String, Object?> extra = const <String, Object?>{}}): _extra = extra,super._();
  factory _AnchorSummary.fromJson(Map<String, dynamic> json) => _$AnchorSummaryFromJson(json);

/// The anchor as content: following someone is a ref, and every other column here is display.
@override@JsonKey(fromJson: refFromJson, toJson: refToJson) final  ContentRef ref;
@override@JsonKey(fromJson: _name) final  String name;
@override@JsonKey(fromJson: _text, includeIfNull: false) final  String? avatar;
/// Follower count as the platform wrote it; null means it did not say, which is not zero.
@override@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) final  int? fans;
/// The room they are in right now, when the platform knows. This is what makes the row tappable: an anchor
/// without a live room opens a profile, not a player.
@override@JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false) final  ContentRef? currentRoom;
@override@JsonKey(fromJson: _text, includeIfNull: false) final  String? description;
 final  Map<String, Object?> _extra;
@override@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of AnchorSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnchorSummaryCopyWith<_AnchorSummary> get copyWith => __$AnchorSummaryCopyWithImpl<_AnchorSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnchorSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnchorSummary&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.fans, fans) || other.fans == fans)&&(identical(other.currentRoom, currentRoom) || other.currentRoom == currentRoom)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.extra, _extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ref,name,avatar,fans,currentRoom,description,const DeepCollectionEquality().hash(_extra));
}



}

/// @nodoc
abstract mixin class _$AnchorSummaryCopyWith<$Res> implements $AnchorSummaryCopyWith<$Res> {
  factory _$AnchorSummaryCopyWith(_AnchorSummary value, $Res Function(_AnchorSummary) _then) = __$AnchorSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: refFromJson, toJson: refToJson) ContentRef ref,@JsonKey(fromJson: _name) String name,@JsonKey(fromJson: _text, includeIfNull: false) String? avatar,@JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? fans,@JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false) ContentRef? currentRoom,@JsonKey(fromJson: _text, includeIfNull: false) String? description,@JsonKey(fromJson: _map, toJson: _mapOut) Map<String, Object?> extra
});




}
/// @nodoc
class __$AnchorSummaryCopyWithImpl<$Res>
    implements _$AnchorSummaryCopyWith<$Res> {
  __$AnchorSummaryCopyWithImpl(this._self, this._then);

  final _AnchorSummary _self;
  final $Res Function(_AnchorSummary) _then;

/// Create a copy of AnchorSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? name = null,Object? avatar = freezed,Object? fans = freezed,Object? currentRoom = freezed,Object? description = freezed,Object? extra = null,}) {
  return _then(_AnchorSummary(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as ContentRef,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,fans: freezed == fans ? _self.fans : fans // ignore: cast_nullable_to_non_nullable
as int?,currentRoom: freezed == currentRoom ? _self.currentRoom : currentRoom // ignore: cast_nullable_to_non_nullable
as ContentRef?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
