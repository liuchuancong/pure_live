// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guide_channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GuideChannel {

/// The guide's own channel id: `tvg-id` in a playlist matches it.
 String get id;/// Every `display-name` of the channel, in file order.
 List<String> get displayNames;/// The channel's icon, when the guide names one.
 String? get iconUrl;
/// Create a copy of GuideChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuideChannelCopyWith<GuideChannel> get copyWith => _$GuideChannelCopyWithImpl<GuideChannel>(this as GuideChannel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GuideChannel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuideChannel&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.displayNames, _this.displayNames)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl));
}


@override
int get hashCode {
  final _this = this as GuideChannel;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.displayNames),_this.iconUrl);
}

@override
String toString() {
  final _this = this as GuideChannel;
  return 'GuideChannel(id: ${_this.id}, displayNames: ${_this.displayNames}, iconUrl: ${_this.iconUrl})';
}


}

/// @nodoc
abstract mixin class $GuideChannelCopyWith<$Res>  {
  factory $GuideChannelCopyWith(GuideChannel value, $Res Function(GuideChannel) _then) = _$GuideChannelCopyWithImpl;
@useResult
$Res call({
 String id, List<String> displayNames, String? iconUrl
});




}
/// @nodoc
class _$GuideChannelCopyWithImpl<$Res>
    implements $GuideChannelCopyWith<$Res> {
  _$GuideChannelCopyWithImpl(this._self, this._then);

  final GuideChannel _self;
  final $Res Function(GuideChannel) _then;

/// Create a copy of GuideChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayNames = null,Object? iconUrl = freezed,}) {
  return _then(GuideChannel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayNames: null == displayNames ? _self.displayNames : displayNames // ignore: cast_nullable_to_non_nullable
as List<String>,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GuideChannel].
extension GuideChannelPatterns on GuideChannel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuideChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuideChannel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuideChannel value)  $default,){
final _that = this;
switch (_that) {
case _GuideChannel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuideChannel value)?  $default,){
final _that = this;
switch (_that) {
case _GuideChannel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  List<String> displayNames,  String? iconUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuideChannel() when $default != null:
return $default(_that.id,_that.displayNames,_that.iconUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  List<String> displayNames,  String? iconUrl)  $default,) {final _that = this;
switch (_that) {
case _GuideChannel():
return $default(_that.id,_that.displayNames,_that.iconUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  List<String> displayNames,  String? iconUrl)?  $default,) {final _that = this;
switch (_that) {
case _GuideChannel() when $default != null:
return $default(_that.id,_that.displayNames,_that.iconUrl);case _:
  return null;

}
}

}

/// @nodoc


class _GuideChannel implements GuideChannel {
  const _GuideChannel({required this.id,  List<String> displayNames = const <String>[], this.iconUrl}): _displayNames = displayNames;
  

/// The guide's own channel id: `tvg-id` in a playlist matches it.
@override final  String id;
/// Every `display-name` of the channel, in file order.
 final  List<String> _displayNames;
/// Every `display-name` of the channel, in file order.
@override@JsonKey() List<String> get displayNames {
  if (_displayNames is EqualUnmodifiableListView) return _displayNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_displayNames);
}

/// The channel's icon, when the guide names one.
@override final  String? iconUrl;

/// Create a copy of GuideChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuideChannelCopyWith<_GuideChannel> get copyWith => __$GuideChannelCopyWithImpl<_GuideChannel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuideChannel&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.displayNames, _displayNames)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_displayNames),iconUrl);
}

@override
String toString() {
    return 'GuideChannel(id: $id, displayNames: $displayNames, iconUrl: $iconUrl)';
}


}

/// @nodoc
abstract mixin class _$GuideChannelCopyWith<$Res> implements $GuideChannelCopyWith<$Res> {
  factory _$GuideChannelCopyWith(_GuideChannel value, $Res Function(_GuideChannel) _then) = __$GuideChannelCopyWithImpl;
@override @useResult
$Res call({
 String id, List<String> displayNames, String? iconUrl
});




}
/// @nodoc
class __$GuideChannelCopyWithImpl<$Res>
    implements _$GuideChannelCopyWith<$Res> {
  __$GuideChannelCopyWithImpl(this._self, this._then);

  final _GuideChannel _self;
  final $Res Function(_GuideChannel) _then;

/// Create a copy of GuideChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayNames = null,Object? iconUrl = freezed,}) {
  return _then(_GuideChannel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayNames: null == displayNames ? _self._displayNames : displayNames // ignore: cast_nullable_to_non_nullable
as List<String>,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
