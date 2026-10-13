// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_sender.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageSender {

 String get userId; String get userName; String? get avatarUrl; String? get userLevel; String get fanBadgeLevel; String get fanBadgeName; LiveMessageColor? get nameColor; List<LiveBadge> get badges; LiveAnchorRole get role; int? get membershipTier;
/// Create a copy of MessageSender
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageSenderCopyWith<MessageSender> get copyWith => _$MessageSenderCopyWithImpl<MessageSender>(this as MessageSender, _$identity);

  /// Serializes this MessageSender to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MessageSender;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageSender&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.userName, _this.userName) || other.userName == _this.userName)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.userLevel, _this.userLevel) || other.userLevel == _this.userLevel)&&(identical(other.fanBadgeLevel, _this.fanBadgeLevel) || other.fanBadgeLevel == _this.fanBadgeLevel)&&(identical(other.fanBadgeName, _this.fanBadgeName) || other.fanBadgeName == _this.fanBadgeName)&&(identical(other.nameColor, _this.nameColor) || other.nameColor == _this.nameColor)&&const DeepCollectionEquality().equals(other.badges, _this.badges)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.membershipTier, _this.membershipTier) || other.membershipTier == _this.membershipTier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MessageSender;
  return Object.hash(runtimeType,_this.userId,_this.userName,_this.avatarUrl,_this.userLevel,_this.fanBadgeLevel,_this.fanBadgeName,_this.nameColor,const DeepCollectionEquality().hash(_this.badges),_this.role,_this.membershipTier);
}

@override
String toString() {
  final _this = this as MessageSender;
  return 'MessageSender(userId: ${_this.userId}, userName: ${_this.userName}, avatarUrl: ${_this.avatarUrl}, userLevel: ${_this.userLevel}, fanBadgeLevel: ${_this.fanBadgeLevel}, fanBadgeName: ${_this.fanBadgeName}, nameColor: ${_this.nameColor}, badges: ${_this.badges}, role: ${_this.role}, membershipTier: ${_this.membershipTier})';
}


}

/// @nodoc
abstract mixin class $MessageSenderCopyWith<$Res>  {
  factory $MessageSenderCopyWith(MessageSender value, $Res Function(MessageSender) _then) = _$MessageSenderCopyWithImpl;
@useResult
$Res call({
 String userId, String userName, String? avatarUrl, String? userLevel, String fanBadgeLevel, String fanBadgeName, LiveMessageColor? nameColor, List<LiveBadge> badges, LiveAnchorRole role, int? membershipTier
});


$LiveMessageColorCopyWith<$Res>? get nameColor;

}
/// @nodoc
class _$MessageSenderCopyWithImpl<$Res>
    implements $MessageSenderCopyWith<$Res> {
  _$MessageSenderCopyWithImpl(this._self, this._then);

  final MessageSender _self;
  final $Res Function(MessageSender) _then;

/// Create a copy of MessageSender
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? userName = null,Object? avatarUrl = freezed,Object? userLevel = freezed,Object? fanBadgeLevel = null,Object? fanBadgeName = null,Object? nameColor = freezed,Object? badges = null,Object? role = null,Object? membershipTier = freezed,}) {
  return _then(MessageSender(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,userLevel: freezed == userLevel ? _self.userLevel : userLevel // ignore: cast_nullable_to_non_nullable
as String?,fanBadgeLevel: null == fanBadgeLevel ? _self.fanBadgeLevel : fanBadgeLevel // ignore: cast_nullable_to_non_nullable
as String,fanBadgeName: null == fanBadgeName ? _self.fanBadgeName : fanBadgeName // ignore: cast_nullable_to_non_nullable
as String,nameColor: freezed == nameColor ? _self.nameColor : nameColor // ignore: cast_nullable_to_non_nullable
as LiveMessageColor?,badges: null == badges ? _self.badges : badges // ignore: cast_nullable_to_non_nullable
as List<LiveBadge>,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as LiveAnchorRole,membershipTier: freezed == membershipTier ? _self.membershipTier : membershipTier // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of MessageSender
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveMessageColorCopyWith<$Res>? get nameColor {
    if (_self.nameColor == null) {
    return null;
  }

  return $LiveMessageColorCopyWith<$Res>(_self.nameColor!, (value) {
    return _then(_self.copyWith(nameColor: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageSender].
extension MessageSenderPatterns on MessageSender {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageSender value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageSender() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageSender value)  $default,){
final _that = this;
switch (_that) {
case _MessageSender():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageSender value)?  $default,){
final _that = this;
switch (_that) {
case _MessageSender() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String userName,  String? avatarUrl,  String? userLevel,  String fanBadgeLevel,  String fanBadgeName,  LiveMessageColor? nameColor,  List<LiveBadge> badges,  LiveAnchorRole role,  int? membershipTier)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageSender() when $default != null:
return $default(_that.userId,_that.userName,_that.avatarUrl,_that.userLevel,_that.fanBadgeLevel,_that.fanBadgeName,_that.nameColor,_that.badges,_that.role,_that.membershipTier);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String userName,  String? avatarUrl,  String? userLevel,  String fanBadgeLevel,  String fanBadgeName,  LiveMessageColor? nameColor,  List<LiveBadge> badges,  LiveAnchorRole role,  int? membershipTier)  $default,) {final _that = this;
switch (_that) {
case _MessageSender():
return $default(_that.userId,_that.userName,_that.avatarUrl,_that.userLevel,_that.fanBadgeLevel,_that.fanBadgeName,_that.nameColor,_that.badges,_that.role,_that.membershipTier);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String userName,  String? avatarUrl,  String? userLevel,  String fanBadgeLevel,  String fanBadgeName,  LiveMessageColor? nameColor,  List<LiveBadge> badges,  LiveAnchorRole role,  int? membershipTier)?  $default,) {final _that = this;
switch (_that) {
case _MessageSender() when $default != null:
return $default(_that.userId,_that.userName,_that.avatarUrl,_that.userLevel,_that.fanBadgeLevel,_that.fanBadgeName,_that.nameColor,_that.badges,_that.role,_that.membershipTier);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageSender implements MessageSender {
  const _MessageSender({this.userId = '', this.userName = '', this.avatarUrl, this.userLevel, this.fanBadgeLevel = '', this.fanBadgeName = '', this.nameColor,  List<LiveBadge> badges = const [], this.role = LiveAnchorRole.viewer, this.membershipTier}): _badges = badges;
  factory _MessageSender.fromJson(Map<String, dynamic> json) => _$MessageSenderFromJson(json);

@override@JsonKey() final  String userId;
@override@JsonKey() final  String userName;
@override final  String? avatarUrl;
@override final  String? userLevel;
@override@JsonKey() final  String fanBadgeLevel;
@override@JsonKey() final  String fanBadgeName;
@override final  LiveMessageColor? nameColor;
 final  List<LiveBadge> _badges;
@override@JsonKey() List<LiveBadge> get badges {
  if (_badges is EqualUnmodifiableListView) return _badges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_badges);
}

@override@JsonKey() final  LiveAnchorRole role;
@override final  int? membershipTier;

/// Create a copy of MessageSender
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageSenderCopyWith<_MessageSender> get copyWith => __$MessageSenderCopyWithImpl<_MessageSender>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageSenderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageSender&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.userLevel, userLevel) || other.userLevel == userLevel)&&(identical(other.fanBadgeLevel, fanBadgeLevel) || other.fanBadgeLevel == fanBadgeLevel)&&(identical(other.fanBadgeName, fanBadgeName) || other.fanBadgeName == fanBadgeName)&&(identical(other.nameColor, nameColor) || other.nameColor == nameColor)&&const DeepCollectionEquality().equals(other.badges, _badges)&&(identical(other.role, role) || other.role == role)&&(identical(other.membershipTier, membershipTier) || other.membershipTier == membershipTier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,userId,userName,avatarUrl,userLevel,fanBadgeLevel,fanBadgeName,nameColor,const DeepCollectionEquality().hash(_badges),role,membershipTier);
}

@override
String toString() {
    return 'MessageSender(userId: $userId, userName: $userName, avatarUrl: $avatarUrl, userLevel: $userLevel, fanBadgeLevel: $fanBadgeLevel, fanBadgeName: $fanBadgeName, nameColor: $nameColor, badges: $badges, role: $role, membershipTier: $membershipTier)';
}


}

/// @nodoc
abstract mixin class _$MessageSenderCopyWith<$Res> implements $MessageSenderCopyWith<$Res> {
  factory _$MessageSenderCopyWith(_MessageSender value, $Res Function(_MessageSender) _then) = __$MessageSenderCopyWithImpl;
@override @useResult
$Res call({
 String userId, String userName, String? avatarUrl, String? userLevel, String fanBadgeLevel, String fanBadgeName, LiveMessageColor? nameColor, List<LiveBadge> badges, LiveAnchorRole role, int? membershipTier
});


@override $LiveMessageColorCopyWith<$Res>? get nameColor;

}
/// @nodoc
class __$MessageSenderCopyWithImpl<$Res>
    implements _$MessageSenderCopyWith<$Res> {
  __$MessageSenderCopyWithImpl(this._self, this._then);

  final _MessageSender _self;
  final $Res Function(_MessageSender) _then;

/// Create a copy of MessageSender
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? userName = null,Object? avatarUrl = freezed,Object? userLevel = freezed,Object? fanBadgeLevel = null,Object? fanBadgeName = null,Object? nameColor = freezed,Object? badges = null,Object? role = null,Object? membershipTier = freezed,}) {
  return _then(_MessageSender(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,userLevel: freezed == userLevel ? _self.userLevel : userLevel // ignore: cast_nullable_to_non_nullable
as String?,fanBadgeLevel: null == fanBadgeLevel ? _self.fanBadgeLevel : fanBadgeLevel // ignore: cast_nullable_to_non_nullable
as String,fanBadgeName: null == fanBadgeName ? _self.fanBadgeName : fanBadgeName // ignore: cast_nullable_to_non_nullable
as String,nameColor: freezed == nameColor ? _self.nameColor : nameColor // ignore: cast_nullable_to_non_nullable
as LiveMessageColor?,badges: null == badges ? _self._badges : badges // ignore: cast_nullable_to_non_nullable
as List<LiveBadge>,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as LiveAnchorRole,membershipTier: freezed == membershipTier ? _self.membershipTier : membershipTier // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of MessageSender
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveMessageColorCopyWith<$Res>? get nameColor {
    if (_self.nameColor == null) {
    return null;
  }

  return $LiveMessageColorCopyWith<$Res>(_self.nameColor!, (value) {
    return _then(_self.copyWith(nameColor: value));
  });
}
}

// dart format on
