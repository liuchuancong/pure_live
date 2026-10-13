// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_room.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveRoom {

 LiveRoomRef get ref; RoomContent get content; RoomAudience get audience; RoomBroadcast get broadcast; RoomLinks get links; RoomGuide get guide; RoomLocal get local;@JsonKey(includeFromJson: false, includeToJson: false) RoomRuntime get runtime; LiveAnchor? get anchor; LiveArea? get area; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<LiveRoom> get copyWith => _$LiveRoomCopyWithImpl<LiveRoom>(this as LiveRoom, _$identity);

  /// Serializes this LiveRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoom;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoom&&(identical(other.ref, _this.ref) || other.ref == _this.ref)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.audience, _this.audience) || other.audience == _this.audience)&&(identical(other.broadcast, _this.broadcast) || other.broadcast == _this.broadcast)&&(identical(other.links, _this.links) || other.links == _this.links)&&(identical(other.guide, _this.guide) || other.guide == _this.guide)&&(identical(other.local, _this.local) || other.local == _this.local)&&(identical(other.runtime, _this.runtime) || other.runtime == _this.runtime)&&(identical(other.anchor, _this.anchor) || other.anchor == _this.anchor)&&(identical(other.area, _this.area) || other.area == _this.area)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoom;
  return Object.hash(runtimeType,_this.ref,_this.content,_this.audience,_this.broadcast,_this.links,_this.guide,_this.local,_this.runtime,_this.anchor,_this.area,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as LiveRoom;
  return 'LiveRoom(ref: ${_this.ref}, content: ${_this.content}, audience: ${_this.audience}, broadcast: ${_this.broadcast}, links: ${_this.links}, guide: ${_this.guide}, local: ${_this.local}, runtime: ${_this.runtime}, anchor: ${_this.anchor}, area: ${_this.area}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $LiveRoomCopyWith<$Res>  {
  factory $LiveRoomCopyWith(LiveRoom value, $Res Function(LiveRoom) _then) = _$LiveRoomCopyWithImpl;
@useResult
$Res call({
 LiveRoomRef ref, RoomContent content, RoomAudience audience, RoomBroadcast broadcast, RoomLinks links, RoomGuide guide, RoomLocal local,@JsonKey(includeFromJson: false, includeToJson: false) RoomRuntime runtime, LiveAnchor? anchor, LiveArea? area, DateTime? createdAt, DateTime? updatedAt
});


$LiveRoomRefCopyWith<$Res> get ref;$RoomContentCopyWith<$Res> get content;$RoomAudienceCopyWith<$Res> get audience;$RoomBroadcastCopyWith<$Res> get broadcast;$RoomLinksCopyWith<$Res> get links;$RoomGuideCopyWith<$Res> get guide;$RoomLocalCopyWith<$Res> get local;$RoomRuntimeCopyWith<$Res> get runtime;$LiveAnchorCopyWith<$Res>? get anchor;$LiveAreaCopyWith<$Res>? get area;

}
/// @nodoc
class _$LiveRoomCopyWithImpl<$Res>
    implements $LiveRoomCopyWith<$Res> {
  _$LiveRoomCopyWithImpl(this._self, this._then);

  final LiveRoom _self;
  final $Res Function(LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? content = null,Object? audience = null,Object? broadcast = null,Object? links = null,Object? guide = null,Object? local = null,Object? runtime = null,Object? anchor = freezed,Object? area = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(LiveRoom(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as LiveRoomRef,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as RoomContent,audience: null == audience ? _self.audience : audience // ignore: cast_nullable_to_non_nullable
as RoomAudience,broadcast: null == broadcast ? _self.broadcast : broadcast // ignore: cast_nullable_to_non_nullable
as RoomBroadcast,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as RoomLinks,guide: null == guide ? _self.guide : guide // ignore: cast_nullable_to_non_nullable
as RoomGuide,local: null == local ? _self.local : local // ignore: cast_nullable_to_non_nullable
as RoomLocal,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as RoomRuntime,anchor: freezed == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as LiveAnchor?,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as LiveArea?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomRefCopyWith<$Res> get ref {
  
  return $LiveRoomRefCopyWith<$Res>(_self.ref, (value) {
    return _then(_self.copyWith(ref: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomContentCopyWith<$Res> get content {
  
  return $RoomContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomAudienceCopyWith<$Res> get audience {
  
  return $RoomAudienceCopyWith<$Res>(_self.audience, (value) {
    return _then(_self.copyWith(audience: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomBroadcastCopyWith<$Res> get broadcast {
  
  return $RoomBroadcastCopyWith<$Res>(_self.broadcast, (value) {
    return _then(_self.copyWith(broadcast: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomLinksCopyWith<$Res> get links {
  
  return $RoomLinksCopyWith<$Res>(_self.links, (value) {
    return _then(_self.copyWith(links: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomGuideCopyWith<$Res> get guide {
  
  return $RoomGuideCopyWith<$Res>(_self.guide, (value) {
    return _then(_self.copyWith(guide: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomLocalCopyWith<$Res> get local {
  
  return $RoomLocalCopyWith<$Res>(_self.local, (value) {
    return _then(_self.copyWith(local: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomRuntimeCopyWith<$Res> get runtime {
  
  return $RoomRuntimeCopyWith<$Res>(_self.runtime, (value) {
    return _then(_self.copyWith(runtime: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAnchorCopyWith<$Res>? get anchor {
    if (_self.anchor == null) {
    return null;
  }

  return $LiveAnchorCopyWith<$Res>(_self.anchor!, (value) {
    return _then(_self.copyWith(anchor: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAreaCopyWith<$Res>? get area {
    if (_self.area == null) {
    return null;
  }

  return $LiveAreaCopyWith<$Res>(_self.area!, (value) {
    return _then(_self.copyWith(area: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveRoom].
extension LiveRoomPatterns on LiveRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoom value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoom value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveRoomRef ref,  RoomContent content,  RoomAudience audience,  RoomBroadcast broadcast,  RoomLinks links,  RoomGuide guide,  RoomLocal local, @JsonKey(includeFromJson: false, includeToJson: false)  RoomRuntime runtime,  LiveAnchor? anchor,  LiveArea? area,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.ref,_that.content,_that.audience,_that.broadcast,_that.links,_that.guide,_that.local,_that.runtime,_that.anchor,_that.area,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveRoomRef ref,  RoomContent content,  RoomAudience audience,  RoomBroadcast broadcast,  RoomLinks links,  RoomGuide guide,  RoomLocal local, @JsonKey(includeFromJson: false, includeToJson: false)  RoomRuntime runtime,  LiveAnchor? anchor,  LiveArea? area,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that.ref,_that.content,_that.audience,_that.broadcast,_that.links,_that.guide,_that.local,_that.runtime,_that.anchor,_that.area,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveRoomRef ref,  RoomContent content,  RoomAudience audience,  RoomBroadcast broadcast,  RoomLinks links,  RoomGuide guide,  RoomLocal local, @JsonKey(includeFromJson: false, includeToJson: false)  RoomRuntime runtime,  LiveAnchor? anchor,  LiveArea? area,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.ref,_that.content,_that.audience,_that.broadcast,_that.links,_that.guide,_that.local,_that.runtime,_that.anchor,_that.area,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoom implements LiveRoom {
  const _LiveRoom({required this.ref, this.content = const RoomContent(), this.audience = const RoomAudience(), this.broadcast = const RoomBroadcast(), this.links = const RoomLinks(), this.guide = const RoomGuide(), this.local = const RoomLocal(), @JsonKey(includeFromJson: false, includeToJson: false) this.runtime = const RoomRuntime(), this.anchor, this.area, this.createdAt, this.updatedAt});
  factory _LiveRoom.fromJson(Map<String, dynamic> json) => _$LiveRoomFromJson(json);

@override final  LiveRoomRef ref;
@override@JsonKey() final  RoomContent content;
@override@JsonKey() final  RoomAudience audience;
@override@JsonKey() final  RoomBroadcast broadcast;
@override@JsonKey() final  RoomLinks links;
@override@JsonKey() final  RoomGuide guide;
@override@JsonKey() final  RoomLocal local;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  RoomRuntime runtime;
@override final  LiveAnchor? anchor;
@override final  LiveArea? area;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomCopyWith<_LiveRoom> get copyWith => __$LiveRoomCopyWithImpl<_LiveRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoom&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.content, content) || other.content == content)&&(identical(other.audience, audience) || other.audience == audience)&&(identical(other.broadcast, broadcast) || other.broadcast == broadcast)&&(identical(other.links, links) || other.links == links)&&(identical(other.guide, guide) || other.guide == guide)&&(identical(other.local, local) || other.local == local)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.anchor, anchor) || other.anchor == anchor)&&(identical(other.area, area) || other.area == area)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ref,content,audience,broadcast,links,guide,local,runtime,anchor,area,createdAt,updatedAt);
}

@override
String toString() {
    return 'LiveRoom(ref: $ref, content: $content, audience: $audience, broadcast: $broadcast, links: $links, guide: $guide, local: $local, runtime: $runtime, anchor: $anchor, area: $area, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomCopyWith<$Res> implements $LiveRoomCopyWith<$Res> {
  factory _$LiveRoomCopyWith(_LiveRoom value, $Res Function(_LiveRoom) _then) = __$LiveRoomCopyWithImpl;
@override @useResult
$Res call({
 LiveRoomRef ref, RoomContent content, RoomAudience audience, RoomBroadcast broadcast, RoomLinks links, RoomGuide guide, RoomLocal local,@JsonKey(includeFromJson: false, includeToJson: false) RoomRuntime runtime, LiveAnchor? anchor, LiveArea? area, DateTime? createdAt, DateTime? updatedAt
});


@override $LiveRoomRefCopyWith<$Res> get ref;@override $RoomContentCopyWith<$Res> get content;@override $RoomAudienceCopyWith<$Res> get audience;@override $RoomBroadcastCopyWith<$Res> get broadcast;@override $RoomLinksCopyWith<$Res> get links;@override $RoomGuideCopyWith<$Res> get guide;@override $RoomLocalCopyWith<$Res> get local;@override $RoomRuntimeCopyWith<$Res> get runtime;@override $LiveAnchorCopyWith<$Res>? get anchor;@override $LiveAreaCopyWith<$Res>? get area;

}
/// @nodoc
class __$LiveRoomCopyWithImpl<$Res>
    implements _$LiveRoomCopyWith<$Res> {
  __$LiveRoomCopyWithImpl(this._self, this._then);

  final _LiveRoom _self;
  final $Res Function(_LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? content = null,Object? audience = null,Object? broadcast = null,Object? links = null,Object? guide = null,Object? local = null,Object? runtime = null,Object? anchor = freezed,Object? area = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_LiveRoom(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as LiveRoomRef,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as RoomContent,audience: null == audience ? _self.audience : audience // ignore: cast_nullable_to_non_nullable
as RoomAudience,broadcast: null == broadcast ? _self.broadcast : broadcast // ignore: cast_nullable_to_non_nullable
as RoomBroadcast,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as RoomLinks,guide: null == guide ? _self.guide : guide // ignore: cast_nullable_to_non_nullable
as RoomGuide,local: null == local ? _self.local : local // ignore: cast_nullable_to_non_nullable
as RoomLocal,runtime: null == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as RoomRuntime,anchor: freezed == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as LiveAnchor?,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as LiveArea?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomRefCopyWith<$Res> get ref {
  
  return $LiveRoomRefCopyWith<$Res>(_self.ref, (value) {
    return _then(_self.copyWith(ref: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomContentCopyWith<$Res> get content {
  
  return $RoomContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomAudienceCopyWith<$Res> get audience {
  
  return $RoomAudienceCopyWith<$Res>(_self.audience, (value) {
    return _then(_self.copyWith(audience: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomBroadcastCopyWith<$Res> get broadcast {
  
  return $RoomBroadcastCopyWith<$Res>(_self.broadcast, (value) {
    return _then(_self.copyWith(broadcast: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomLinksCopyWith<$Res> get links {
  
  return $RoomLinksCopyWith<$Res>(_self.links, (value) {
    return _then(_self.copyWith(links: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomGuideCopyWith<$Res> get guide {
  
  return $RoomGuideCopyWith<$Res>(_self.guide, (value) {
    return _then(_self.copyWith(guide: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomLocalCopyWith<$Res> get local {
  
  return $RoomLocalCopyWith<$Res>(_self.local, (value) {
    return _then(_self.copyWith(local: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomRuntimeCopyWith<$Res> get runtime {
  
  return $RoomRuntimeCopyWith<$Res>(_self.runtime, (value) {
    return _then(_self.copyWith(runtime: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAnchorCopyWith<$Res>? get anchor {
    if (_self.anchor == null) {
    return null;
  }

  return $LiveAnchorCopyWith<$Res>(_self.anchor!, (value) {
    return _then(_self.copyWith(anchor: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveAreaCopyWith<$Res>? get area {
    if (_self.area == null) {
    return null;
  }

  return $LiveAreaCopyWith<$Res>(_self.area!, (value) {
    return _then(_self.copyWith(area: value));
  });
}
}

// dart format on
