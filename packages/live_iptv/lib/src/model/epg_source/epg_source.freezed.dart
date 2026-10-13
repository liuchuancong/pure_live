// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'epg_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EpgSource {

/// The source's id.
 String get id;/// The name shown in the interface.
 String get name;/// An http(s) URL, or the path of an imported file.
 String get source;/// When it was last imported or synced successfully.
 DateTime? get lastRefresh;/// When it was first imported.
 DateTime? get createdAt;/// Whether a sync may refresh it by itself.
 bool get autoUpdate;
/// Create a copy of EpgSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpgSourceCopyWith<EpgSource> get copyWith => _$EpgSourceCopyWithImpl<EpgSource>(this as EpgSource, _$identity);

  /// Serializes this EpgSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EpgSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpgSource&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.lastRefresh, _this.lastRefresh) || other.lastRefresh == _this.lastRefresh)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.autoUpdate, _this.autoUpdate) || other.autoUpdate == _this.autoUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EpgSource;
  return Object.hash(runtimeType,_this.id,_this.name,_this.source,_this.lastRefresh,_this.createdAt,_this.autoUpdate);
}

@override
String toString() {
  final _this = this as EpgSource;
  return 'EpgSource(id: ${_this.id}, name: ${_this.name}, source: ${_this.source}, lastRefresh: ${_this.lastRefresh}, createdAt: ${_this.createdAt}, autoUpdate: ${_this.autoUpdate})';
}


}

/// @nodoc
abstract mixin class $EpgSourceCopyWith<$Res>  {
  factory $EpgSourceCopyWith(EpgSource value, $Res Function(EpgSource) _then) = _$EpgSourceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String source, DateTime? lastRefresh, DateTime? createdAt, bool autoUpdate
});




}
/// @nodoc
class _$EpgSourceCopyWithImpl<$Res>
    implements $EpgSourceCopyWith<$Res> {
  _$EpgSourceCopyWithImpl(this._self, this._then);

  final EpgSource _self;
  final $Res Function(EpgSource) _then;

/// Create a copy of EpgSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? source = null,Object? lastRefresh = freezed,Object? createdAt = freezed,Object? autoUpdate = null,}) {
  return _then(EpgSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,lastRefresh: freezed == lastRefresh ? _self.lastRefresh : lastRefresh // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,autoUpdate: null == autoUpdate ? _self.autoUpdate : autoUpdate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EpgSource].
extension EpgSourcePatterns on EpgSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpgSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpgSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpgSource value)  $default,){
final _that = this;
switch (_that) {
case _EpgSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpgSource value)?  $default,){
final _that = this;
switch (_that) {
case _EpgSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String source,  DateTime? lastRefresh,  DateTime? createdAt,  bool autoUpdate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpgSource() when $default != null:
return $default(_that.id,_that.name,_that.source,_that.lastRefresh,_that.createdAt,_that.autoUpdate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String source,  DateTime? lastRefresh,  DateTime? createdAt,  bool autoUpdate)  $default,) {final _that = this;
switch (_that) {
case _EpgSource():
return $default(_that.id,_that.name,_that.source,_that.lastRefresh,_that.createdAt,_that.autoUpdate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String source,  DateTime? lastRefresh,  DateTime? createdAt,  bool autoUpdate)?  $default,) {final _that = this;
switch (_that) {
case _EpgSource() when $default != null:
return $default(_that.id,_that.name,_that.source,_that.lastRefresh,_that.createdAt,_that.autoUpdate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EpgSource implements EpgSource {
  const _EpgSource({required this.id, required this.name, required this.source, this.lastRefresh, this.createdAt, this.autoUpdate = true});
  factory _EpgSource.fromJson(Map<String, dynamic> json) => _$EpgSourceFromJson(json);

/// The source's id.
@override final  String id;
/// The name shown in the interface.
@override final  String name;
/// An http(s) URL, or the path of an imported file.
@override final  String source;
/// When it was last imported or synced successfully.
@override final  DateTime? lastRefresh;
/// When it was first imported.
@override final  DateTime? createdAt;
/// Whether a sync may refresh it by itself.
@override@JsonKey() final  bool autoUpdate;

/// Create a copy of EpgSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpgSourceCopyWith<_EpgSource> get copyWith => __$EpgSourceCopyWithImpl<_EpgSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpgSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpgSource&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.source, source) || other.source == source)&&(identical(other.lastRefresh, lastRefresh) || other.lastRefresh == lastRefresh)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.autoUpdate, autoUpdate) || other.autoUpdate == autoUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,source,lastRefresh,createdAt,autoUpdate);
}

@override
String toString() {
    return 'EpgSource(id: $id, name: $name, source: $source, lastRefresh: $lastRefresh, createdAt: $createdAt, autoUpdate: $autoUpdate)';
}


}

/// @nodoc
abstract mixin class _$EpgSourceCopyWith<$Res> implements $EpgSourceCopyWith<$Res> {
  factory _$EpgSourceCopyWith(_EpgSource value, $Res Function(_EpgSource) _then) = __$EpgSourceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String source, DateTime? lastRefresh, DateTime? createdAt, bool autoUpdate
});




}
/// @nodoc
class __$EpgSourceCopyWithImpl<$Res>
    implements _$EpgSourceCopyWith<$Res> {
  __$EpgSourceCopyWithImpl(this._self, this._then);

  final _EpgSource _self;
  final $Res Function(_EpgSource) _then;

/// Create a copy of EpgSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? source = null,Object? lastRefresh = freezed,Object? createdAt = freezed,Object? autoUpdate = null,}) {
  return _then(_EpgSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,lastRefresh: freezed == lastRefresh ? _self.lastRefresh : lastRefresh // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,autoUpdate: null == autoUpdate ? _self.autoUpdate : autoUpdate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
