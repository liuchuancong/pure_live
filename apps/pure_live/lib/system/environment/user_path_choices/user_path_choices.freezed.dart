// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_path_choices.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserPathChoices {

/// Area name to absolute directory path; empty means the app defaults
/// everywhere.
 Map<String, String> get customByArea;
/// Create a copy of UserPathChoices
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserPathChoicesCopyWith<UserPathChoices> get copyWith => _$UserPathChoicesCopyWithImpl<UserPathChoices>(this as UserPathChoices, _$identity);

  /// Serializes this UserPathChoices to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserPathChoices;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserPathChoices&&const DeepCollectionEquality().equals(other.customByArea, _this.customByArea));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserPathChoices;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.customByArea));
}

@override
String toString() {
  final _this = this as UserPathChoices;
  return 'UserPathChoices(customByArea: ${_this.customByArea})';
}


}

/// @nodoc
abstract mixin class $UserPathChoicesCopyWith<$Res>  {
  factory $UserPathChoicesCopyWith(UserPathChoices value, $Res Function(UserPathChoices) _then) = _$UserPathChoicesCopyWithImpl;
@useResult
$Res call({
 Map<String, String> customByArea
});




}
/// @nodoc
class _$UserPathChoicesCopyWithImpl<$Res>
    implements $UserPathChoicesCopyWith<$Res> {
  _$UserPathChoicesCopyWithImpl(this._self, this._then);

  final UserPathChoices _self;
  final $Res Function(UserPathChoices) _then;

/// Create a copy of UserPathChoices
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? customByArea = null,}) {
  return _then(UserPathChoices(
customByArea: null == customByArea ? _self.customByArea : customByArea // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserPathChoices].
extension UserPathChoicesPatterns on UserPathChoices {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserPathChoices value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserPathChoices() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserPathChoices value)  $default,){
final _that = this;
switch (_that) {
case _UserPathChoices():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserPathChoices value)?  $default,){
final _that = this;
switch (_that) {
case _UserPathChoices() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, String> customByArea)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserPathChoices() when $default != null:
return $default(_that.customByArea);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, String> customByArea)  $default,) {final _that = this;
switch (_that) {
case _UserPathChoices():
return $default(_that.customByArea);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, String> customByArea)?  $default,) {final _that = this;
switch (_that) {
case _UserPathChoices() when $default != null:
return $default(_that.customByArea);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserPathChoices extends UserPathChoices {
  const _UserPathChoices({ Map<String, String> customByArea = const {}}): _customByArea = customByArea,super._();
  factory _UserPathChoices.fromJson(Map<String, dynamic> json) => _$UserPathChoicesFromJson(json);

/// Area name to absolute directory path; empty means the app defaults
/// everywhere.
 final  Map<String, String> _customByArea;
/// Area name to absolute directory path; empty means the app defaults
/// everywhere.
@override@JsonKey() Map<String, String> get customByArea {
  if (_customByArea is EqualUnmodifiableMapView) return _customByArea;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_customByArea);
}


/// Create a copy of UserPathChoices
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserPathChoicesCopyWith<_UserPathChoices> get copyWith => __$UserPathChoicesCopyWithImpl<_UserPathChoices>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserPathChoicesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserPathChoices&&const DeepCollectionEquality().equals(other.customByArea, _customByArea));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_customByArea));
}

@override
String toString() {
    return 'UserPathChoices(customByArea: $customByArea)';
}


}

/// @nodoc
abstract mixin class _$UserPathChoicesCopyWith<$Res> implements $UserPathChoicesCopyWith<$Res> {
  factory _$UserPathChoicesCopyWith(_UserPathChoices value, $Res Function(_UserPathChoices) _then) = __$UserPathChoicesCopyWithImpl;
@override @useResult
$Res call({
 Map<String, String> customByArea
});




}
/// @nodoc
class __$UserPathChoicesCopyWithImpl<$Res>
    implements _$UserPathChoicesCopyWith<$Res> {
  __$UserPathChoicesCopyWithImpl(this._self, this._then);

  final _UserPathChoices _self;
  final $Res Function(_UserPathChoices) _then;

/// Create a copy of UserPathChoices
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? customByArea = null,}) {
  return _then(_UserPathChoices(
customByArea: null == customByArea ? _self._customByArea : customByArea // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
