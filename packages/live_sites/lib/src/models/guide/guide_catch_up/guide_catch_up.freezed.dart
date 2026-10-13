// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guide_catch_up.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GuideCatchUp {

 String? get url; bool get active; int? get start; int? get end; String? get mode; String? get urlTemplate; double? get windowDays; double? get correctionHours; String? get catchupId;
/// Create a copy of GuideCatchUp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuideCatchUpCopyWith<GuideCatchUp> get copyWith => _$GuideCatchUpCopyWithImpl<GuideCatchUp>(this as GuideCatchUp, _$identity);

  /// Serializes this GuideCatchUp to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GuideCatchUp;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuideCatchUp&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.urlTemplate, _this.urlTemplate) || other.urlTemplate == _this.urlTemplate)&&(identical(other.windowDays, _this.windowDays) || other.windowDays == _this.windowDays)&&(identical(other.correctionHours, _this.correctionHours) || other.correctionHours == _this.correctionHours)&&(identical(other.catchupId, _this.catchupId) || other.catchupId == _this.catchupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GuideCatchUp;
  return Object.hash(runtimeType,_this.url,_this.active,_this.start,_this.end,_this.mode,_this.urlTemplate,_this.windowDays,_this.correctionHours,_this.catchupId);
}

@override
String toString() {
  final _this = this as GuideCatchUp;
  return 'GuideCatchUp(url: ${_this.url}, active: ${_this.active}, start: ${_this.start}, end: ${_this.end}, mode: ${_this.mode}, urlTemplate: ${_this.urlTemplate}, windowDays: ${_this.windowDays}, correctionHours: ${_this.correctionHours}, catchupId: ${_this.catchupId})';
}


}

/// @nodoc
abstract mixin class $GuideCatchUpCopyWith<$Res>  {
  factory $GuideCatchUpCopyWith(GuideCatchUp value, $Res Function(GuideCatchUp) _then) = _$GuideCatchUpCopyWithImpl;
@useResult
$Res call({
 String? url, bool active, int? start, int? end, String? mode, String? urlTemplate, double? windowDays, double? correctionHours, String? catchupId
});




}
/// @nodoc
class _$GuideCatchUpCopyWithImpl<$Res>
    implements $GuideCatchUpCopyWith<$Res> {
  _$GuideCatchUpCopyWithImpl(this._self, this._then);

  final GuideCatchUp _self;
  final $Res Function(GuideCatchUp) _then;

/// Create a copy of GuideCatchUp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = freezed,Object? active = null,Object? start = freezed,Object? end = freezed,Object? mode = freezed,Object? urlTemplate = freezed,Object? windowDays = freezed,Object? correctionHours = freezed,Object? catchupId = freezed,}) {
  return _then(GuideCatchUp(
url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,urlTemplate: freezed == urlTemplate ? _self.urlTemplate : urlTemplate // ignore: cast_nullable_to_non_nullable
as String?,windowDays: freezed == windowDays ? _self.windowDays : windowDays // ignore: cast_nullable_to_non_nullable
as double?,correctionHours: freezed == correctionHours ? _self.correctionHours : correctionHours // ignore: cast_nullable_to_non_nullable
as double?,catchupId: freezed == catchupId ? _self.catchupId : catchupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GuideCatchUp].
extension GuideCatchUpPatterns on GuideCatchUp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuideCatchUp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuideCatchUp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuideCatchUp value)  $default,){
final _that = this;
switch (_that) {
case _GuideCatchUp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuideCatchUp value)?  $default,){
final _that = this;
switch (_that) {
case _GuideCatchUp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? url,  bool active,  int? start,  int? end,  String? mode,  String? urlTemplate,  double? windowDays,  double? correctionHours,  String? catchupId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuideCatchUp() when $default != null:
return $default(_that.url,_that.active,_that.start,_that.end,_that.mode,_that.urlTemplate,_that.windowDays,_that.correctionHours,_that.catchupId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? url,  bool active,  int? start,  int? end,  String? mode,  String? urlTemplate,  double? windowDays,  double? correctionHours,  String? catchupId)  $default,) {final _that = this;
switch (_that) {
case _GuideCatchUp():
return $default(_that.url,_that.active,_that.start,_that.end,_that.mode,_that.urlTemplate,_that.windowDays,_that.correctionHours,_that.catchupId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? url,  bool active,  int? start,  int? end,  String? mode,  String? urlTemplate,  double? windowDays,  double? correctionHours,  String? catchupId)?  $default,) {final _that = this;
switch (_that) {
case _GuideCatchUp() when $default != null:
return $default(_that.url,_that.active,_that.start,_that.end,_that.mode,_that.urlTemplate,_that.windowDays,_that.correctionHours,_that.catchupId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GuideCatchUp extends GuideCatchUp {
  const _GuideCatchUp({this.url, this.active = false, this.start, this.end, this.mode, this.urlTemplate, this.windowDays, this.correctionHours, this.catchupId}): super._();
  factory _GuideCatchUp.fromJson(Map<String, dynamic> json) => _$GuideCatchUpFromJson(json);

@override final  String? url;
@override@JsonKey() final  bool active;
@override final  int? start;
@override final  int? end;
@override final  String? mode;
@override final  String? urlTemplate;
@override final  double? windowDays;
@override final  double? correctionHours;
@override final  String? catchupId;

/// Create a copy of GuideCatchUp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuideCatchUpCopyWith<_GuideCatchUp> get copyWith => __$GuideCatchUpCopyWithImpl<_GuideCatchUp>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GuideCatchUpToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuideCatchUp&&(identical(other.url, url) || other.url == url)&&(identical(other.active, active) || other.active == active)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.urlTemplate, urlTemplate) || other.urlTemplate == urlTemplate)&&(identical(other.windowDays, windowDays) || other.windowDays == windowDays)&&(identical(other.correctionHours, correctionHours) || other.correctionHours == correctionHours)&&(identical(other.catchupId, catchupId) || other.catchupId == catchupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,active,start,end,mode,urlTemplate,windowDays,correctionHours,catchupId);
}

@override
String toString() {
    return 'GuideCatchUp(url: $url, active: $active, start: $start, end: $end, mode: $mode, urlTemplate: $urlTemplate, windowDays: $windowDays, correctionHours: $correctionHours, catchupId: $catchupId)';
}


}

/// @nodoc
abstract mixin class _$GuideCatchUpCopyWith<$Res> implements $GuideCatchUpCopyWith<$Res> {
  factory _$GuideCatchUpCopyWith(_GuideCatchUp value, $Res Function(_GuideCatchUp) _then) = __$GuideCatchUpCopyWithImpl;
@override @useResult
$Res call({
 String? url, bool active, int? start, int? end, String? mode, String? urlTemplate, double? windowDays, double? correctionHours, String? catchupId
});




}
/// @nodoc
class __$GuideCatchUpCopyWithImpl<$Res>
    implements _$GuideCatchUpCopyWith<$Res> {
  __$GuideCatchUpCopyWithImpl(this._self, this._then);

  final _GuideCatchUp _self;
  final $Res Function(_GuideCatchUp) _then;

/// Create a copy of GuideCatchUp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = freezed,Object? active = null,Object? start = freezed,Object? end = freezed,Object? mode = freezed,Object? urlTemplate = freezed,Object? windowDays = freezed,Object? correctionHours = freezed,Object? catchupId = freezed,}) {
  return _then(_GuideCatchUp(
url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,urlTemplate: freezed == urlTemplate ? _self.urlTemplate : urlTemplate // ignore: cast_nullable_to_non_nullable
as String?,windowDays: freezed == windowDays ? _self.windowDays : windowDays // ignore: cast_nullable_to_non_nullable
as double?,correctionHours: freezed == correctionHours ? _self.correctionHours : correctionHours // ignore: cast_nullable_to_non_nullable
as double?,catchupId: freezed == catchupId ? _self.catchupId : catchupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
