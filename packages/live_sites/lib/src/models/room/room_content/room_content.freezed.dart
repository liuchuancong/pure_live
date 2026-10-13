// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomContent {

 String get title; String get coverUrl; String? get introduction; String? get notice; List<LiveBadge> get badges; List<String> get platformTags;
/// Create a copy of RoomContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomContentCopyWith<RoomContent> get copyWith => _$RoomContentCopyWithImpl<RoomContent>(this as RoomContent, _$identity);

  /// Serializes this RoomContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomContent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomContent&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.introduction, _this.introduction) || other.introduction == _this.introduction)&&(identical(other.notice, _this.notice) || other.notice == _this.notice)&&const DeepCollectionEquality().equals(other.badges, _this.badges)&&const DeepCollectionEquality().equals(other.platformTags, _this.platformTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomContent;
  return Object.hash(runtimeType,_this.title,_this.coverUrl,_this.introduction,_this.notice,const DeepCollectionEquality().hash(_this.badges),const DeepCollectionEquality().hash(_this.platformTags));
}

@override
String toString() {
  final _this = this as RoomContent;
  return 'RoomContent(title: ${_this.title}, coverUrl: ${_this.coverUrl}, introduction: ${_this.introduction}, notice: ${_this.notice}, badges: ${_this.badges}, platformTags: ${_this.platformTags})';
}


}

/// @nodoc
abstract mixin class $RoomContentCopyWith<$Res>  {
  factory $RoomContentCopyWith(RoomContent value, $Res Function(RoomContent) _then) = _$RoomContentCopyWithImpl;
@useResult
$Res call({
 String title, String coverUrl, String? introduction, String? notice, List<LiveBadge> badges, List<String> platformTags
});




}
/// @nodoc
class _$RoomContentCopyWithImpl<$Res>
    implements $RoomContentCopyWith<$Res> {
  _$RoomContentCopyWithImpl(this._self, this._then);

  final RoomContent _self;
  final $Res Function(RoomContent) _then;

/// Create a copy of RoomContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? coverUrl = null,Object? introduction = freezed,Object? notice = freezed,Object? badges = null,Object? platformTags = null,}) {
  return _then(RoomContent(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as String?,badges: null == badges ? _self.badges : badges // ignore: cast_nullable_to_non_nullable
as List<LiveBadge>,platformTags: null == platformTags ? _self.platformTags : platformTags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomContent].
extension RoomContentPatterns on RoomContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomContent value)  $default,){
final _that = this;
switch (_that) {
case _RoomContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomContent value)?  $default,){
final _that = this;
switch (_that) {
case _RoomContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String coverUrl,  String? introduction,  String? notice,  List<LiveBadge> badges,  List<String> platformTags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomContent() when $default != null:
return $default(_that.title,_that.coverUrl,_that.introduction,_that.notice,_that.badges,_that.platformTags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String coverUrl,  String? introduction,  String? notice,  List<LiveBadge> badges,  List<String> platformTags)  $default,) {final _that = this;
switch (_that) {
case _RoomContent():
return $default(_that.title,_that.coverUrl,_that.introduction,_that.notice,_that.badges,_that.platformTags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String coverUrl,  String? introduction,  String? notice,  List<LiveBadge> badges,  List<String> platformTags)?  $default,) {final _that = this;
switch (_that) {
case _RoomContent() when $default != null:
return $default(_that.title,_that.coverUrl,_that.introduction,_that.notice,_that.badges,_that.platformTags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomContent extends RoomContent {
  const _RoomContent({this.title = '', this.coverUrl = '', this.introduction, this.notice,  List<LiveBadge> badges = const [],  List<String> platformTags = const []}): _badges = badges,_platformTags = platformTags,super._();
  factory _RoomContent.fromJson(Map<String, dynamic> json) => _$RoomContentFromJson(json);

@override@JsonKey() final  String title;
@override@JsonKey() final  String coverUrl;
@override final  String? introduction;
@override final  String? notice;
 final  List<LiveBadge> _badges;
@override@JsonKey() List<LiveBadge> get badges {
  if (_badges is EqualUnmodifiableListView) return _badges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_badges);
}

 final  List<String> _platformTags;
@override@JsonKey() List<String> get platformTags {
  if (_platformTags is EqualUnmodifiableListView) return _platformTags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_platformTags);
}


/// Create a copy of RoomContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomContentCopyWith<_RoomContent> get copyWith => __$RoomContentCopyWithImpl<_RoomContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomContentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomContent&&(identical(other.title, title) || other.title == title)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.introduction, introduction) || other.introduction == introduction)&&(identical(other.notice, notice) || other.notice == notice)&&const DeepCollectionEquality().equals(other.badges, _badges)&&const DeepCollectionEquality().equals(other.platformTags, _platformTags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title,coverUrl,introduction,notice,const DeepCollectionEquality().hash(_badges),const DeepCollectionEquality().hash(_platformTags));
}

@override
String toString() {
    return 'RoomContent(title: $title, coverUrl: $coverUrl, introduction: $introduction, notice: $notice, badges: $badges, platformTags: $platformTags)';
}


}

/// @nodoc
abstract mixin class _$RoomContentCopyWith<$Res> implements $RoomContentCopyWith<$Res> {
  factory _$RoomContentCopyWith(_RoomContent value, $Res Function(_RoomContent) _then) = __$RoomContentCopyWithImpl;
@override @useResult
$Res call({
 String title, String coverUrl, String? introduction, String? notice, List<LiveBadge> badges, List<String> platformTags
});




}
/// @nodoc
class __$RoomContentCopyWithImpl<$Res>
    implements _$RoomContentCopyWith<$Res> {
  __$RoomContentCopyWithImpl(this._self, this._then);

  final _RoomContent _self;
  final $Res Function(_RoomContent) _then;

/// Create a copy of RoomContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? coverUrl = null,Object? introduction = freezed,Object? notice = freezed,Object? badges = null,Object? platformTags = null,}) {
  return _then(_RoomContent(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,introduction: freezed == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String?,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as String?,badges: null == badges ? _self._badges : badges // ignore: cast_nullable_to_non_nullable
as List<LiveBadge>,platformTags: null == platformTags ? _self._platformTags : platformTags // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
