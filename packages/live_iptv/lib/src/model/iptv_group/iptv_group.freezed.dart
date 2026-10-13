// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'iptv_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IptvGroup {

 String get name; int get order; bool get pinned; bool get hidden;
/// Create a copy of IptvGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IptvGroupCopyWith<IptvGroup> get copyWith => _$IptvGroupCopyWithImpl<IptvGroup>(this as IptvGroup, _$identity);

  /// Serializes this IptvGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IptvGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IptvGroup&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.order, _this.order) || other.order == _this.order)&&(identical(other.pinned, _this.pinned) || other.pinned == _this.pinned)&&(identical(other.hidden, _this.hidden) || other.hidden == _this.hidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IptvGroup;
  return Object.hash(runtimeType,_this.name,_this.order,_this.pinned,_this.hidden);
}

@override
String toString() {
  final _this = this as IptvGroup;
  return 'IptvGroup(name: ${_this.name}, order: ${_this.order}, pinned: ${_this.pinned}, hidden: ${_this.hidden})';
}


}

/// @nodoc
abstract mixin class $IptvGroupCopyWith<$Res>  {
  factory $IptvGroupCopyWith(IptvGroup value, $Res Function(IptvGroup) _then) = _$IptvGroupCopyWithImpl;
@useResult
$Res call({
 String name, int order, bool pinned, bool hidden
});




}
/// @nodoc
class _$IptvGroupCopyWithImpl<$Res>
    implements $IptvGroupCopyWith<$Res> {
  _$IptvGroupCopyWithImpl(this._self, this._then);

  final IptvGroup _self;
  final $Res Function(IptvGroup) _then;

/// Create a copy of IptvGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? order = null,Object? pinned = null,Object? hidden = null,}) {
  return _then(IptvGroup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [IptvGroup].
extension IptvGroupPatterns on IptvGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IptvGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IptvGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IptvGroup value)  $default,){
final _that = this;
switch (_that) {
case _IptvGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IptvGroup value)?  $default,){
final _that = this;
switch (_that) {
case _IptvGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int order,  bool pinned,  bool hidden)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IptvGroup() when $default != null:
return $default(_that.name,_that.order,_that.pinned,_that.hidden);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int order,  bool pinned,  bool hidden)  $default,) {final _that = this;
switch (_that) {
case _IptvGroup():
return $default(_that.name,_that.order,_that.pinned,_that.hidden);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int order,  bool pinned,  bool hidden)?  $default,) {final _that = this;
switch (_that) {
case _IptvGroup() when $default != null:
return $default(_that.name,_that.order,_that.pinned,_that.hidden);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IptvGroup implements IptvGroup {
  const _IptvGroup({required this.name, this.order = 0, this.pinned = false, this.hidden = false});
  factory _IptvGroup.fromJson(Map<String, dynamic> json) => _$IptvGroupFromJson(json);

@override final  String name;
@override@JsonKey() final  int order;
@override@JsonKey() final  bool pinned;
@override@JsonKey() final  bool hidden;

/// Create a copy of IptvGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IptvGroupCopyWith<_IptvGroup> get copyWith => __$IptvGroupCopyWithImpl<_IptvGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IptvGroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IptvGroup&&(identical(other.name, name) || other.name == name)&&(identical(other.order, order) || other.order == order)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.hidden, hidden) || other.hidden == hidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,order,pinned,hidden);
}

@override
String toString() {
    return 'IptvGroup(name: $name, order: $order, pinned: $pinned, hidden: $hidden)';
}


}

/// @nodoc
abstract mixin class _$IptvGroupCopyWith<$Res> implements $IptvGroupCopyWith<$Res> {
  factory _$IptvGroupCopyWith(_IptvGroup value, $Res Function(_IptvGroup) _then) = __$IptvGroupCopyWithImpl;
@override @useResult
$Res call({
 String name, int order, bool pinned, bool hidden
});




}
/// @nodoc
class __$IptvGroupCopyWithImpl<$Res>
    implements _$IptvGroupCopyWith<$Res> {
  __$IptvGroupCopyWithImpl(this._self, this._then);

  final _IptvGroup _self;
  final $Res Function(_IptvGroup) _then;

/// Create a copy of IptvGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? order = null,Object? pinned = null,Object? hidden = null,}) {
  return _then(_IptvGroup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
