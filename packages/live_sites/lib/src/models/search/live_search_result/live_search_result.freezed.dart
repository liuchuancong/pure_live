// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveSearchResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSearchResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LiveSearchResult()';
}


}

/// @nodoc
class $LiveSearchResultCopyWith<$Res>  {
$LiveSearchResultCopyWith(LiveSearchResult _, $Res Function(LiveSearchResult) __);
}


/// Adds pattern-matching-related methods to [LiveSearchResult].
extension LiveSearchResultPatterns on LiveSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RoomSearchResult value)?  room,TResult Function( AnchorSearchResult value)?  anchor,TResult Function( AreaSearchResult value)?  area,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RoomSearchResult() when room != null:
return room(_that);case AnchorSearchResult() when anchor != null:
return anchor(_that);case AreaSearchResult() when area != null:
return area(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RoomSearchResult value)  room,required TResult Function( AnchorSearchResult value)  anchor,required TResult Function( AreaSearchResult value)  area,}){
final _that = this;
switch (_that) {
case RoomSearchResult():
return room(_that);case AnchorSearchResult():
return anchor(_that);case AreaSearchResult():
return area(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RoomSearchResult value)?  room,TResult? Function( AnchorSearchResult value)?  anchor,TResult? Function( AreaSearchResult value)?  area,}){
final _that = this;
switch (_that) {
case RoomSearchResult() when room != null:
return room(_that);case AnchorSearchResult() when anchor != null:
return anchor(_that);case AreaSearchResult() when area != null:
return area(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( LiveRoom room)?  room,TResult Function( LiveAnchor anchor)?  anchor,TResult Function( LiveArea area)?  area,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RoomSearchResult() when room != null:
return room(_that.room);case AnchorSearchResult() when anchor != null:
return anchor(_that.anchor);case AreaSearchResult() when area != null:
return area(_that.area);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( LiveRoom room)  room,required TResult Function( LiveAnchor anchor)  anchor,required TResult Function( LiveArea area)  area,}) {final _that = this;
switch (_that) {
case RoomSearchResult():
return room(_that.room);case AnchorSearchResult():
return anchor(_that.anchor);case AreaSearchResult():
return area(_that.area);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( LiveRoom room)?  room,TResult? Function( LiveAnchor anchor)?  anchor,TResult? Function( LiveArea area)?  area,}) {final _that = this;
switch (_that) {
case RoomSearchResult() when room != null:
return room(_that.room);case AnchorSearchResult() when anchor != null:
return anchor(_that.anchor);case AreaSearchResult() when area != null:
return area(_that.area);case _:
  return null;

}
}

}

/// @nodoc


class RoomSearchResult implements LiveSearchResult {
  const RoomSearchResult(this.room);
  

 final  LiveRoom room;

/// Create a copy of LiveSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomSearchResultCopyWith<RoomSearchResult> get copyWith => _$RoomSearchResultCopyWithImpl<RoomSearchResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomSearchResult&&(identical(other.room, room) || other.room == room));
}


@override
int get hashCode {
    return Object.hash(runtimeType,room);
}

@override
String toString() {
    return 'LiveSearchResult.room(room: $room)';
}


}

/// @nodoc
abstract mixin class $RoomSearchResultCopyWith<$Res> implements $LiveSearchResultCopyWith<$Res> {
  factory $RoomSearchResultCopyWith(RoomSearchResult value, $Res Function(RoomSearchResult) _then) = _$RoomSearchResultCopyWithImpl;
@useResult
$Res call({
 LiveRoom room
});




}
/// @nodoc
class _$RoomSearchResultCopyWithImpl<$Res>
    implements $RoomSearchResultCopyWith<$Res> {
  _$RoomSearchResultCopyWithImpl(this._self, this._then);

  final RoomSearchResult _self;
  final $Res Function(RoomSearchResult) _then;

/// Create a copy of LiveSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? room = null,}) {
  return _then(RoomSearchResult(
null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoom,
  ));
}


}

/// @nodoc


class AnchorSearchResult implements LiveSearchResult {
  const AnchorSearchResult(this.anchor);
  

 final  LiveAnchor anchor;

/// Create a copy of LiveSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnchorSearchResultCopyWith<AnchorSearchResult> get copyWith => _$AnchorSearchResultCopyWithImpl<AnchorSearchResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AnchorSearchResult&&(identical(other.anchor, anchor) || other.anchor == anchor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,anchor);
}

@override
String toString() {
    return 'LiveSearchResult.anchor(anchor: $anchor)';
}


}

/// @nodoc
abstract mixin class $AnchorSearchResultCopyWith<$Res> implements $LiveSearchResultCopyWith<$Res> {
  factory $AnchorSearchResultCopyWith(AnchorSearchResult value, $Res Function(AnchorSearchResult) _then) = _$AnchorSearchResultCopyWithImpl;
@useResult
$Res call({
 LiveAnchor anchor
});




}
/// @nodoc
class _$AnchorSearchResultCopyWithImpl<$Res>
    implements $AnchorSearchResultCopyWith<$Res> {
  _$AnchorSearchResultCopyWithImpl(this._self, this._then);

  final AnchorSearchResult _self;
  final $Res Function(AnchorSearchResult) _then;

/// Create a copy of LiveSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? anchor = null,}) {
  return _then(AnchorSearchResult(
null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as LiveAnchor,
  ));
}


}

/// @nodoc


class AreaSearchResult implements LiveSearchResult {
  const AreaSearchResult(this.area);
  

 final  LiveArea area;

/// Create a copy of LiveSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AreaSearchResultCopyWith<AreaSearchResult> get copyWith => _$AreaSearchResultCopyWithImpl<AreaSearchResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AreaSearchResult&&(identical(other.area, area) || other.area == area));
}


@override
int get hashCode {
    return Object.hash(runtimeType,area);
}

@override
String toString() {
    return 'LiveSearchResult.area(area: $area)';
}


}

/// @nodoc
abstract mixin class $AreaSearchResultCopyWith<$Res> implements $LiveSearchResultCopyWith<$Res> {
  factory $AreaSearchResultCopyWith(AreaSearchResult value, $Res Function(AreaSearchResult) _then) = _$AreaSearchResultCopyWithImpl;
@useResult
$Res call({
 LiveArea area
});




}
/// @nodoc
class _$AreaSearchResultCopyWithImpl<$Res>
    implements $AreaSearchResultCopyWith<$Res> {
  _$AreaSearchResultCopyWithImpl(this._self, this._then);

  final AreaSearchResult _self;
  final $Res Function(AreaSearchResult) _then;

/// Create a copy of LiveSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? area = null,}) {
  return _then(AreaSearchResult(
null == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as LiveArea,
  ));
}


}

// dart format on
