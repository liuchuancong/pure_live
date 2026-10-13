// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'epg_programme.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EpgProgramme {

/// The guide channel this programme belongs to (its `channelId`).
 String get channelId;/// When it starts, in UTC.
 DateTime get start;/// When it stops, in UTC.
 DateTime get stop;/// The source the guide came from.
 String get sourceId;/// Its title.
 String get title;/// Its subtitle, when the guide has one.
 String? get subtitle;/// Its description.
 String? get description;/// Its category or genre.
 String? get category;/// The episode number, in whatever form the guide writes it.
 String? get episodeNum;/// The provider's id for replaying this programme, when the guide
/// carries one; catch-up with `vod`-style modes needs it.
 String? get catchupId;
/// Create a copy of EpgProgramme
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpgProgrammeCopyWith<EpgProgramme> get copyWith => _$EpgProgrammeCopyWithImpl<EpgProgramme>(this as EpgProgramme, _$identity);

  /// Serializes this EpgProgramme to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EpgProgramme;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpgProgramme&&(identical(other.channelId, _this.channelId) || other.channelId == _this.channelId)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.stop, _this.stop) || other.stop == _this.stop)&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.subtitle, _this.subtitle) || other.subtitle == _this.subtitle)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.episodeNum, _this.episodeNum) || other.episodeNum == _this.episodeNum)&&(identical(other.catchupId, _this.catchupId) || other.catchupId == _this.catchupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EpgProgramme;
  return Object.hash(runtimeType,_this.channelId,_this.start,_this.stop,_this.sourceId,_this.title,_this.subtitle,_this.description,_this.category,_this.episodeNum,_this.catchupId);
}

@override
String toString() {
  final _this = this as EpgProgramme;
  return 'EpgProgramme(channelId: ${_this.channelId}, start: ${_this.start}, stop: ${_this.stop}, sourceId: ${_this.sourceId}, title: ${_this.title}, subtitle: ${_this.subtitle}, description: ${_this.description}, category: ${_this.category}, episodeNum: ${_this.episodeNum}, catchupId: ${_this.catchupId})';
}


}

/// @nodoc
abstract mixin class $EpgProgrammeCopyWith<$Res>  {
  factory $EpgProgrammeCopyWith(EpgProgramme value, $Res Function(EpgProgramme) _then) = _$EpgProgrammeCopyWithImpl;
@useResult
$Res call({
 String channelId, DateTime start, DateTime stop, String sourceId, String title, String? subtitle, String? description, String? category, String? episodeNum, String? catchupId
});




}
/// @nodoc
class _$EpgProgrammeCopyWithImpl<$Res>
    implements $EpgProgrammeCopyWith<$Res> {
  _$EpgProgrammeCopyWithImpl(this._self, this._then);

  final EpgProgramme _self;
  final $Res Function(EpgProgramme) _then;

/// Create a copy of EpgProgramme
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channelId = null,Object? start = null,Object? stop = null,Object? sourceId = null,Object? title = null,Object? subtitle = freezed,Object? description = freezed,Object? category = freezed,Object? episodeNum = freezed,Object? catchupId = freezed,}) {
  return _then(EpgProgramme(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,stop: null == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as DateTime,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,episodeNum: freezed == episodeNum ? _self.episodeNum : episodeNum // ignore: cast_nullable_to_non_nullable
as String?,catchupId: freezed == catchupId ? _self.catchupId : catchupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EpgProgramme].
extension EpgProgrammePatterns on EpgProgramme {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpgProgramme value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpgProgramme() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpgProgramme value)  $default,){
final _that = this;
switch (_that) {
case _EpgProgramme():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpgProgramme value)?  $default,){
final _that = this;
switch (_that) {
case _EpgProgramme() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String channelId,  DateTime start,  DateTime stop,  String sourceId,  String title,  String? subtitle,  String? description,  String? category,  String? episodeNum,  String? catchupId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpgProgramme() when $default != null:
return $default(_that.channelId,_that.start,_that.stop,_that.sourceId,_that.title,_that.subtitle,_that.description,_that.category,_that.episodeNum,_that.catchupId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String channelId,  DateTime start,  DateTime stop,  String sourceId,  String title,  String? subtitle,  String? description,  String? category,  String? episodeNum,  String? catchupId)  $default,) {final _that = this;
switch (_that) {
case _EpgProgramme():
return $default(_that.channelId,_that.start,_that.stop,_that.sourceId,_that.title,_that.subtitle,_that.description,_that.category,_that.episodeNum,_that.catchupId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String channelId,  DateTime start,  DateTime stop,  String sourceId,  String title,  String? subtitle,  String? description,  String? category,  String? episodeNum,  String? catchupId)?  $default,) {final _that = this;
switch (_that) {
case _EpgProgramme() when $default != null:
return $default(_that.channelId,_that.start,_that.stop,_that.sourceId,_that.title,_that.subtitle,_that.description,_that.category,_that.episodeNum,_that.catchupId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EpgProgramme implements EpgProgramme {
  const _EpgProgramme({required this.channelId, required this.start, required this.stop, this.sourceId = '', this.title = '', this.subtitle, this.description, this.category, this.episodeNum, this.catchupId});
  factory _EpgProgramme.fromJson(Map<String, dynamic> json) => _$EpgProgrammeFromJson(json);

/// The guide channel this programme belongs to (its `channelId`).
@override final  String channelId;
/// When it starts, in UTC.
@override final  DateTime start;
/// When it stops, in UTC.
@override final  DateTime stop;
/// The source the guide came from.
@override@JsonKey() final  String sourceId;
/// Its title.
@override@JsonKey() final  String title;
/// Its subtitle, when the guide has one.
@override final  String? subtitle;
/// Its description.
@override final  String? description;
/// Its category or genre.
@override final  String? category;
/// The episode number, in whatever form the guide writes it.
@override final  String? episodeNum;
/// The provider's id for replaying this programme, when the guide
/// carries one; catch-up with `vod`-style modes needs it.
@override final  String? catchupId;

/// Create a copy of EpgProgramme
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpgProgrammeCopyWith<_EpgProgramme> get copyWith => __$EpgProgrammeCopyWithImpl<_EpgProgramme>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpgProgrammeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpgProgramme&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.start, start) || other.start == start)&&(identical(other.stop, stop) || other.stop == stop)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.episodeNum, episodeNum) || other.episodeNum == episodeNum)&&(identical(other.catchupId, catchupId) || other.catchupId == catchupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,channelId,start,stop,sourceId,title,subtitle,description,category,episodeNum,catchupId);
}

@override
String toString() {
    return 'EpgProgramme(channelId: $channelId, start: $start, stop: $stop, sourceId: $sourceId, title: $title, subtitle: $subtitle, description: $description, category: $category, episodeNum: $episodeNum, catchupId: $catchupId)';
}


}

/// @nodoc
abstract mixin class _$EpgProgrammeCopyWith<$Res> implements $EpgProgrammeCopyWith<$Res> {
  factory _$EpgProgrammeCopyWith(_EpgProgramme value, $Res Function(_EpgProgramme) _then) = __$EpgProgrammeCopyWithImpl;
@override @useResult
$Res call({
 String channelId, DateTime start, DateTime stop, String sourceId, String title, String? subtitle, String? description, String? category, String? episodeNum, String? catchupId
});




}
/// @nodoc
class __$EpgProgrammeCopyWithImpl<$Res>
    implements _$EpgProgrammeCopyWith<$Res> {
  __$EpgProgrammeCopyWithImpl(this._self, this._then);

  final _EpgProgramme _self;
  final $Res Function(_EpgProgramme) _then;

/// Create a copy of EpgProgramme
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channelId = null,Object? start = null,Object? stop = null,Object? sourceId = null,Object? title = null,Object? subtitle = freezed,Object? description = freezed,Object? category = freezed,Object? episodeNum = freezed,Object? catchupId = freezed,}) {
  return _then(_EpgProgramme(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,stop: null == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as DateTime,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,episodeNum: freezed == episodeNum ? _self.episodeNum : episodeNum // ignore: cast_nullable_to_non_nullable
as String?,catchupId: freezed == catchupId ? _self.catchupId : catchupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
