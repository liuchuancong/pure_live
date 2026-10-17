// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_room.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LibraryRoom {

 LiveRoom get room; DateTime get followedAt; int get position; String? get note; List<String> get groupIds;
/// Create a copy of LibraryRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryRoomCopyWith<LibraryRoom> get copyWith => _$LibraryRoomCopyWithImpl<LibraryRoom>(this as LibraryRoom, _$identity);

  /// Serializes this LibraryRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LibraryRoom;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryRoom&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.followedAt, _this.followedAt) || other.followedAt == _this.followedAt)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.note, _this.note) || other.note == _this.note)&&const DeepCollectionEquality().equals(other.groupIds, _this.groupIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LibraryRoom;
  return Object.hash(runtimeType,_this.room,_this.followedAt,_this.position,_this.note,const DeepCollectionEquality().hash(_this.groupIds));
}

@override
String toString() {
  final _this = this as LibraryRoom;
  return 'LibraryRoom(room: ${_this.room}, followedAt: ${_this.followedAt}, position: ${_this.position}, note: ${_this.note}, groupIds: ${_this.groupIds})';
}


}

/// @nodoc
abstract mixin class $LibraryRoomCopyWith<$Res>  {
  factory $LibraryRoomCopyWith(LibraryRoom value, $Res Function(LibraryRoom) _then) = _$LibraryRoomCopyWithImpl;
@useResult
$Res call({
 LiveRoom room, DateTime followedAt, int position, String? note, List<String> groupIds
});


$LiveRoomCopyWith<$Res> get room;

}
/// @nodoc
class _$LibraryRoomCopyWithImpl<$Res>
    implements $LibraryRoomCopyWith<$Res> {
  _$LibraryRoomCopyWithImpl(this._self, this._then);

  final LibraryRoom _self;
  final $Res Function(LibraryRoom) _then;

/// Create a copy of LibraryRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? followedAt = null,Object? position = null,Object? note = freezed,Object? groupIds = null,}) {
  return _then(LibraryRoom(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoom,followedAt: null == followedAt ? _self.followedAt : followedAt // ignore: cast_nullable_to_non_nullable
as DateTime,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,groupIds: null == groupIds ? _self.groupIds : groupIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of LibraryRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<$Res> get room {
  
  return $LiveRoomCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibraryRoom].
extension LibraryRoomPatterns on LibraryRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryRoom value)  $default,){
final _that = this;
switch (_that) {
case _LibraryRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryRoom value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveRoom room,  DateTime followedAt,  int position,  String? note,  List<String> groupIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryRoom() when $default != null:
return $default(_that.room,_that.followedAt,_that.position,_that.note,_that.groupIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveRoom room,  DateTime followedAt,  int position,  String? note,  List<String> groupIds)  $default,) {final _that = this;
switch (_that) {
case _LibraryRoom():
return $default(_that.room,_that.followedAt,_that.position,_that.note,_that.groupIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveRoom room,  DateTime followedAt,  int position,  String? note,  List<String> groupIds)?  $default,) {final _that = this;
switch (_that) {
case _LibraryRoom() when $default != null:
return $default(_that.room,_that.followedAt,_that.position,_that.note,_that.groupIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibraryRoom implements LibraryRoom {
  const _LibraryRoom({required this.room, required this.followedAt, this.position = 0, this.note,  List<String> groupIds = const <String>[]}): _groupIds = groupIds;
  factory _LibraryRoom.fromJson(Map<String, dynamic> json) => _$LibraryRoomFromJson(json);

@override final  LiveRoom room;
@override final  DateTime followedAt;
@override@JsonKey() final  int position;
@override final  String? note;
 final  List<String> _groupIds;
@override@JsonKey() List<String> get groupIds {
  if (_groupIds is EqualUnmodifiableListView) return _groupIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groupIds);
}


/// Create a copy of LibraryRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryRoomCopyWith<_LibraryRoom> get copyWith => __$LibraryRoomCopyWithImpl<_LibraryRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibraryRoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryRoom&&(identical(other.room, room) || other.room == room)&&(identical(other.followedAt, followedAt) || other.followedAt == followedAt)&&(identical(other.position, position) || other.position == position)&&(identical(other.note, note) || other.note == note)&&const DeepCollectionEquality().equals(other.groupIds, _groupIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,followedAt,position,note,const DeepCollectionEquality().hash(_groupIds));
}

@override
String toString() {
    return 'LibraryRoom(room: $room, followedAt: $followedAt, position: $position, note: $note, groupIds: $groupIds)';
}


}

/// @nodoc
abstract mixin class _$LibraryRoomCopyWith<$Res> implements $LibraryRoomCopyWith<$Res> {
  factory _$LibraryRoomCopyWith(_LibraryRoom value, $Res Function(_LibraryRoom) _then) = __$LibraryRoomCopyWithImpl;
@override @useResult
$Res call({
 LiveRoom room, DateTime followedAt, int position, String? note, List<String> groupIds
});


@override $LiveRoomCopyWith<$Res> get room;

}
/// @nodoc
class __$LibraryRoomCopyWithImpl<$Res>
    implements _$LibraryRoomCopyWith<$Res> {
  __$LibraryRoomCopyWithImpl(this._self, this._then);

  final _LibraryRoom _self;
  final $Res Function(_LibraryRoom) _then;

/// Create a copy of LibraryRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? followedAt = null,Object? position = null,Object? note = freezed,Object? groupIds = null,}) {
  return _then(_LibraryRoom(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoom,followedAt: null == followedAt ? _self.followedAt : followedAt // ignore: cast_nullable_to_non_nullable
as DateTime,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,groupIds: null == groupIds ? _self._groupIds : groupIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of LibraryRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<$Res> get room {
  
  return $LiveRoomCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}


/// @nodoc
mixin _$FollowGroup {

 String get id; String get name; int get position;
/// Create a copy of FollowGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowGroupCopyWith<FollowGroup> get copyWith => _$FollowGroupCopyWithImpl<FollowGroup>(this as FollowGroup, _$identity);

  /// Serializes this FollowGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FollowGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowGroup&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.position, _this.position) || other.position == _this.position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FollowGroup;
  return Object.hash(runtimeType,_this.id,_this.name,_this.position);
}

@override
String toString() {
  final _this = this as FollowGroup;
  return 'FollowGroup(id: ${_this.id}, name: ${_this.name}, position: ${_this.position})';
}


}

/// @nodoc
abstract mixin class $FollowGroupCopyWith<$Res>  {
  factory $FollowGroupCopyWith(FollowGroup value, $Res Function(FollowGroup) _then) = _$FollowGroupCopyWithImpl;
@useResult
$Res call({
 String id, String name, int position
});




}
/// @nodoc
class _$FollowGroupCopyWithImpl<$Res>
    implements $FollowGroupCopyWith<$Res> {
  _$FollowGroupCopyWithImpl(this._self, this._then);

  final FollowGroup _self;
  final $Res Function(FollowGroup) _then;

/// Create a copy of FollowGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? position = null,}) {
  return _then(FollowGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowGroup].
extension FollowGroupPatterns on FollowGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowGroup value)  $default,){
final _that = this;
switch (_that) {
case _FollowGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowGroup value)?  $default,){
final _that = this;
switch (_that) {
case _FollowGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowGroup() when $default != null:
return $default(_that.id,_that.name,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int position)  $default,) {final _that = this;
switch (_that) {
case _FollowGroup():
return $default(_that.id,_that.name,_that.position);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int position)?  $default,) {final _that = this;
switch (_that) {
case _FollowGroup() when $default != null:
return $default(_that.id,_that.name,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FollowGroup implements FollowGroup {
  const _FollowGroup({required this.id, required this.name, this.position = 0});
  factory _FollowGroup.fromJson(Map<String, dynamic> json) => _$FollowGroupFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  int position;

/// Create a copy of FollowGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowGroupCopyWith<_FollowGroup> get copyWith => __$FollowGroupCopyWithImpl<_FollowGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FollowGroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,position);
}

@override
String toString() {
    return 'FollowGroup(id: $id, name: $name, position: $position)';
}


}

/// @nodoc
abstract mixin class _$FollowGroupCopyWith<$Res> implements $FollowGroupCopyWith<$Res> {
  factory _$FollowGroupCopyWith(_FollowGroup value, $Res Function(_FollowGroup) _then) = __$FollowGroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int position
});




}
/// @nodoc
class __$FollowGroupCopyWithImpl<$Res>
    implements _$FollowGroupCopyWith<$Res> {
  __$FollowGroupCopyWithImpl(this._self, this._then);

  final _FollowGroup _self;
  final $Res Function(_FollowGroup) _then;

/// Create a copy of FollowGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? position = null,}) {
  return _then(_FollowGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WatchRecord {

 LiveRoom get room; DateTime get watchedAt; int get seq; double? get progress;@DurationMillisConverter() Duration? get position;
/// Create a copy of WatchRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatchRecordCopyWith<WatchRecord> get copyWith => _$WatchRecordCopyWithImpl<WatchRecord>(this as WatchRecord, _$identity);

  /// Serializes this WatchRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WatchRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WatchRecord&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.watchedAt, _this.watchedAt) || other.watchedAt == _this.watchedAt)&&(identical(other.seq, _this.seq) || other.seq == _this.seq)&&(identical(other.progress, _this.progress) || other.progress == _this.progress)&&(identical(other.position, _this.position) || other.position == _this.position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WatchRecord;
  return Object.hash(runtimeType,_this.room,_this.watchedAt,_this.seq,_this.progress,_this.position);
}

@override
String toString() {
  final _this = this as WatchRecord;
  return 'WatchRecord(room: ${_this.room}, watchedAt: ${_this.watchedAt}, seq: ${_this.seq}, progress: ${_this.progress}, position: ${_this.position})';
}


}

/// @nodoc
abstract mixin class $WatchRecordCopyWith<$Res>  {
  factory $WatchRecordCopyWith(WatchRecord value, $Res Function(WatchRecord) _then) = _$WatchRecordCopyWithImpl;
@useResult
$Res call({
 LiveRoom room, DateTime watchedAt, int seq, double? progress,@DurationMillisConverter() Duration? position
});


$LiveRoomCopyWith<$Res> get room;

}
/// @nodoc
class _$WatchRecordCopyWithImpl<$Res>
    implements $WatchRecordCopyWith<$Res> {
  _$WatchRecordCopyWithImpl(this._self, this._then);

  final WatchRecord _self;
  final $Res Function(WatchRecord) _then;

/// Create a copy of WatchRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? watchedAt = null,Object? seq = null,Object? progress = freezed,Object? position = freezed,}) {
  return _then(WatchRecord(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoom,watchedAt: null == watchedAt ? _self.watchedAt : watchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}
/// Create a copy of WatchRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<$Res> get room {
  
  return $LiveRoomCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}


/// Adds pattern-matching-related methods to [WatchRecord].
extension WatchRecordPatterns on WatchRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WatchRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WatchRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WatchRecord value)  $default,){
final _that = this;
switch (_that) {
case _WatchRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WatchRecord value)?  $default,){
final _that = this;
switch (_that) {
case _WatchRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveRoom room,  DateTime watchedAt,  int seq,  double? progress, @DurationMillisConverter()  Duration? position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WatchRecord() when $default != null:
return $default(_that.room,_that.watchedAt,_that.seq,_that.progress,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveRoom room,  DateTime watchedAt,  int seq,  double? progress, @DurationMillisConverter()  Duration? position)  $default,) {final _that = this;
switch (_that) {
case _WatchRecord():
return $default(_that.room,_that.watchedAt,_that.seq,_that.progress,_that.position);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveRoom room,  DateTime watchedAt,  int seq,  double? progress, @DurationMillisConverter()  Duration? position)?  $default,) {final _that = this;
switch (_that) {
case _WatchRecord() when $default != null:
return $default(_that.room,_that.watchedAt,_that.seq,_that.progress,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WatchRecord implements WatchRecord {
  const _WatchRecord({required this.room, required this.watchedAt, this.seq = 0, this.progress, @DurationMillisConverter() this.position});
  factory _WatchRecord.fromJson(Map<String, dynamic> json) => _$WatchRecordFromJson(json);

@override final  LiveRoom room;
@override final  DateTime watchedAt;
@override@JsonKey() final  int seq;
@override final  double? progress;
@override@DurationMillisConverter() final  Duration? position;

/// Create a copy of WatchRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatchRecordCopyWith<_WatchRecord> get copyWith => __$WatchRecordCopyWithImpl<_WatchRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WatchRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WatchRecord&&(identical(other.room, room) || other.room == room)&&(identical(other.watchedAt, watchedAt) || other.watchedAt == watchedAt)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,watchedAt,seq,progress,position);
}

@override
String toString() {
    return 'WatchRecord(room: $room, watchedAt: $watchedAt, seq: $seq, progress: $progress, position: $position)';
}


}

/// @nodoc
abstract mixin class _$WatchRecordCopyWith<$Res> implements $WatchRecordCopyWith<$Res> {
  factory _$WatchRecordCopyWith(_WatchRecord value, $Res Function(_WatchRecord) _then) = __$WatchRecordCopyWithImpl;
@override @useResult
$Res call({
 LiveRoom room, DateTime watchedAt, int seq, double? progress,@DurationMillisConverter() Duration? position
});


@override $LiveRoomCopyWith<$Res> get room;

}
/// @nodoc
class __$WatchRecordCopyWithImpl<$Res>
    implements _$WatchRecordCopyWith<$Res> {
  __$WatchRecordCopyWithImpl(this._self, this._then);

  final _WatchRecord _self;
  final $Res Function(_WatchRecord) _then;

/// Create a copy of WatchRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? watchedAt = null,Object? seq = null,Object? progress = freezed,Object? position = freezed,}) {
  return _then(_WatchRecord(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoom,watchedAt: null == watchedAt ? _self.watchedAt : watchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

/// Create a copy of WatchRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<$Res> get room {
  
  return $LiveRoomCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}

// dart format on
