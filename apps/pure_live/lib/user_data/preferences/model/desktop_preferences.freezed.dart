// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desktop_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DesktopPreferences {

/// What pressing the close button means.
///
/// Read and written by the two functions below rather than by the generator's
/// enum decode, which throws on anything it does not recognise: a document
/// written by a newer build — one that added a fourth case — would otherwise
/// stop this build from starting at all. A rolled-back install is an ordinary
/// path for a desktop app, and a saved preference must never be able to say
/// "no interface for you". An unrecognised or mistyped value costs a reset to
/// the shipping default, which is the whole price.
@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson) CloseAction get closeAction;/// Whether an icon sits in the notification area / menu bar at all.
///
/// Turning this off makes [closeAction] `hideToTray` meaningless, and the
/// shell then quits on close by design rather than leaving a windowless
/// process nobody can reach.
 bool get showTrayIcon;/// Whether the window's place and size are remembered between starts.
 bool get rememberWindowBounds;/// Whether the app registers itself to start at sign-in.
 bool get launchAtLogin;/// Whether a start comes up in the tray without showing a window.
 bool get startHidden;/// Whether the interface may be destroyed to give its memory back once the
/// window has been out of sight for [idleReclaimAfter].
///
/// Never while something is recording or a stream is being pulled — the
/// shell checks that separately, because the rebuild path is where a dropped
/// segment would be found days later, not now.
 bool get reclaimWhenIdle;/// How long out of sight and untouched before the interface is reclaimed.
 Duration get idleReclaimAfter;/// Whether the platform's translucent window material may be used.
 bool get effects;/// Whether the GPU may draw. Off means the software rasteriser.
 bool get hardwareAcceleration;/// Whether the app may post system notifications (recording finished, a
/// followed channel went live).
///
/// The body of a notification lands in the system's notification centre and
/// on the lock screen, so nothing identifying a private room belongs there —
/// which is why this is one switch over all of them.
 bool get systemNotifications;
/// Create a copy of DesktopPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopPreferencesCopyWith<DesktopPreferences> get copyWith => _$DesktopPreferencesCopyWithImpl<DesktopPreferences>(this as DesktopPreferences, _$identity);

  /// Serializes this DesktopPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DesktopPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopPreferences&&(identical(other.closeAction, _this.closeAction) || other.closeAction == _this.closeAction)&&(identical(other.showTrayIcon, _this.showTrayIcon) || other.showTrayIcon == _this.showTrayIcon)&&(identical(other.rememberWindowBounds, _this.rememberWindowBounds) || other.rememberWindowBounds == _this.rememberWindowBounds)&&(identical(other.launchAtLogin, _this.launchAtLogin) || other.launchAtLogin == _this.launchAtLogin)&&(identical(other.startHidden, _this.startHidden) || other.startHidden == _this.startHidden)&&(identical(other.reclaimWhenIdle, _this.reclaimWhenIdle) || other.reclaimWhenIdle == _this.reclaimWhenIdle)&&(identical(other.idleReclaimAfter, _this.idleReclaimAfter) || other.idleReclaimAfter == _this.idleReclaimAfter)&&(identical(other.effects, _this.effects) || other.effects == _this.effects)&&(identical(other.hardwareAcceleration, _this.hardwareAcceleration) || other.hardwareAcceleration == _this.hardwareAcceleration)&&(identical(other.systemNotifications, _this.systemNotifications) || other.systemNotifications == _this.systemNotifications));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DesktopPreferences;
  return Object.hash(runtimeType,_this.closeAction,_this.showTrayIcon,_this.rememberWindowBounds,_this.launchAtLogin,_this.startHidden,_this.reclaimWhenIdle,_this.idleReclaimAfter,_this.effects,_this.hardwareAcceleration,_this.systemNotifications);
}

@override
String toString() {
  final _this = this as DesktopPreferences;
  return 'DesktopPreferences(closeAction: ${_this.closeAction}, showTrayIcon: ${_this.showTrayIcon}, rememberWindowBounds: ${_this.rememberWindowBounds}, launchAtLogin: ${_this.launchAtLogin}, startHidden: ${_this.startHidden}, reclaimWhenIdle: ${_this.reclaimWhenIdle}, idleReclaimAfter: ${_this.idleReclaimAfter}, effects: ${_this.effects}, hardwareAcceleration: ${_this.hardwareAcceleration}, systemNotifications: ${_this.systemNotifications})';
}


}

/// @nodoc
abstract mixin class $DesktopPreferencesCopyWith<$Res>  {
  factory $DesktopPreferencesCopyWith(DesktopPreferences value, $Res Function(DesktopPreferences) _then) = _$DesktopPreferencesCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson) CloseAction closeAction, bool showTrayIcon, bool rememberWindowBounds, bool launchAtLogin, bool startHidden, bool reclaimWhenIdle, Duration idleReclaimAfter, bool effects, bool hardwareAcceleration, bool systemNotifications
});




}
/// @nodoc
class _$DesktopPreferencesCopyWithImpl<$Res>
    implements $DesktopPreferencesCopyWith<$Res> {
  _$DesktopPreferencesCopyWithImpl(this._self, this._then);

  final DesktopPreferences _self;
  final $Res Function(DesktopPreferences) _then;

/// Create a copy of DesktopPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? closeAction = null,Object? showTrayIcon = null,Object? rememberWindowBounds = null,Object? launchAtLogin = null,Object? startHidden = null,Object? reclaimWhenIdle = null,Object? idleReclaimAfter = null,Object? effects = null,Object? hardwareAcceleration = null,Object? systemNotifications = null,}) {
  return _then(DesktopPreferences(
closeAction: null == closeAction ? _self.closeAction : closeAction // ignore: cast_nullable_to_non_nullable
as CloseAction,showTrayIcon: null == showTrayIcon ? _self.showTrayIcon : showTrayIcon // ignore: cast_nullable_to_non_nullable
as bool,rememberWindowBounds: null == rememberWindowBounds ? _self.rememberWindowBounds : rememberWindowBounds // ignore: cast_nullable_to_non_nullable
as bool,launchAtLogin: null == launchAtLogin ? _self.launchAtLogin : launchAtLogin // ignore: cast_nullable_to_non_nullable
as bool,startHidden: null == startHidden ? _self.startHidden : startHidden // ignore: cast_nullable_to_non_nullable
as bool,reclaimWhenIdle: null == reclaimWhenIdle ? _self.reclaimWhenIdle : reclaimWhenIdle // ignore: cast_nullable_to_non_nullable
as bool,idleReclaimAfter: null == idleReclaimAfter ? _self.idleReclaimAfter : idleReclaimAfter // ignore: cast_nullable_to_non_nullable
as Duration,effects: null == effects ? _self.effects : effects // ignore: cast_nullable_to_non_nullable
as bool,hardwareAcceleration: null == hardwareAcceleration ? _self.hardwareAcceleration : hardwareAcceleration // ignore: cast_nullable_to_non_nullable
as bool,systemNotifications: null == systemNotifications ? _self.systemNotifications : systemNotifications // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DesktopPreferences].
extension DesktopPreferencesPatterns on DesktopPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesktopPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesktopPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesktopPreferences value)  $default,){
final _that = this;
switch (_that) {
case _DesktopPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesktopPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _DesktopPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson)  CloseAction closeAction,  bool showTrayIcon,  bool rememberWindowBounds,  bool launchAtLogin,  bool startHidden,  bool reclaimWhenIdle,  Duration idleReclaimAfter,  bool effects,  bool hardwareAcceleration,  bool systemNotifications)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesktopPreferences() when $default != null:
return $default(_that.closeAction,_that.showTrayIcon,_that.rememberWindowBounds,_that.launchAtLogin,_that.startHidden,_that.reclaimWhenIdle,_that.idleReclaimAfter,_that.effects,_that.hardwareAcceleration,_that.systemNotifications);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson)  CloseAction closeAction,  bool showTrayIcon,  bool rememberWindowBounds,  bool launchAtLogin,  bool startHidden,  bool reclaimWhenIdle,  Duration idleReclaimAfter,  bool effects,  bool hardwareAcceleration,  bool systemNotifications)  $default,) {final _that = this;
switch (_that) {
case _DesktopPreferences():
return $default(_that.closeAction,_that.showTrayIcon,_that.rememberWindowBounds,_that.launchAtLogin,_that.startHidden,_that.reclaimWhenIdle,_that.idleReclaimAfter,_that.effects,_that.hardwareAcceleration,_that.systemNotifications);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson)  CloseAction closeAction,  bool showTrayIcon,  bool rememberWindowBounds,  bool launchAtLogin,  bool startHidden,  bool reclaimWhenIdle,  Duration idleReclaimAfter,  bool effects,  bool hardwareAcceleration,  bool systemNotifications)?  $default,) {final _that = this;
switch (_that) {
case _DesktopPreferences() when $default != null:
return $default(_that.closeAction,_that.showTrayIcon,_that.rememberWindowBounds,_that.launchAtLogin,_that.startHidden,_that.reclaimWhenIdle,_that.idleReclaimAfter,_that.effects,_that.hardwareAcceleration,_that.systemNotifications);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DesktopPreferences implements DesktopPreferences {
  const _DesktopPreferences({@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson) this.closeAction = CloseAction.hideToTray, this.showTrayIcon = true, this.rememberWindowBounds = true, this.launchAtLogin = false, this.startHidden = false, this.reclaimWhenIdle = false, this.idleReclaimAfter = const Duration(minutes: 30), this.effects = true, this.hardwareAcceleration = true, this.systemNotifications = true});
  factory _DesktopPreferences.fromJson(Map<String, dynamic> json) => _$DesktopPreferencesFromJson(json);

/// What pressing the close button means.
///
/// Read and written by the two functions below rather than by the generator's
/// enum decode, which throws on anything it does not recognise: a document
/// written by a newer build — one that added a fourth case — would otherwise
/// stop this build from starting at all. A rolled-back install is an ordinary
/// path for a desktop app, and a saved preference must never be able to say
/// "no interface for you". An unrecognised or mistyped value costs a reset to
/// the shipping default, which is the whole price.
@override@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson) final  CloseAction closeAction;
/// Whether an icon sits in the notification area / menu bar at all.
///
/// Turning this off makes [closeAction] `hideToTray` meaningless, and the
/// shell then quits on close by design rather than leaving a windowless
/// process nobody can reach.
@override@JsonKey() final  bool showTrayIcon;
/// Whether the window's place and size are remembered between starts.
@override@JsonKey() final  bool rememberWindowBounds;
/// Whether the app registers itself to start at sign-in.
@override@JsonKey() final  bool launchAtLogin;
/// Whether a start comes up in the tray without showing a window.
@override@JsonKey() final  bool startHidden;
/// Whether the interface may be destroyed to give its memory back once the
/// window has been out of sight for [idleReclaimAfter].
///
/// Never while something is recording or a stream is being pulled — the
/// shell checks that separately, because the rebuild path is where a dropped
/// segment would be found days later, not now.
@override@JsonKey() final  bool reclaimWhenIdle;
/// How long out of sight and untouched before the interface is reclaimed.
@override@JsonKey() final  Duration idleReclaimAfter;
/// Whether the platform's translucent window material may be used.
@override@JsonKey() final  bool effects;
/// Whether the GPU may draw. Off means the software rasteriser.
@override@JsonKey() final  bool hardwareAcceleration;
/// Whether the app may post system notifications (recording finished, a
/// followed channel went live).
///
/// The body of a notification lands in the system's notification centre and
/// on the lock screen, so nothing identifying a private room belongs there —
/// which is why this is one switch over all of them.
@override@JsonKey() final  bool systemNotifications;

/// Create a copy of DesktopPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesktopPreferencesCopyWith<_DesktopPreferences> get copyWith => __$DesktopPreferencesCopyWithImpl<_DesktopPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesktopPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesktopPreferences&&(identical(other.closeAction, closeAction) || other.closeAction == closeAction)&&(identical(other.showTrayIcon, showTrayIcon) || other.showTrayIcon == showTrayIcon)&&(identical(other.rememberWindowBounds, rememberWindowBounds) || other.rememberWindowBounds == rememberWindowBounds)&&(identical(other.launchAtLogin, launchAtLogin) || other.launchAtLogin == launchAtLogin)&&(identical(other.startHidden, startHidden) || other.startHidden == startHidden)&&(identical(other.reclaimWhenIdle, reclaimWhenIdle) || other.reclaimWhenIdle == reclaimWhenIdle)&&(identical(other.idleReclaimAfter, idleReclaimAfter) || other.idleReclaimAfter == idleReclaimAfter)&&(identical(other.effects, effects) || other.effects == effects)&&(identical(other.hardwareAcceleration, hardwareAcceleration) || other.hardwareAcceleration == hardwareAcceleration)&&(identical(other.systemNotifications, systemNotifications) || other.systemNotifications == systemNotifications));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,closeAction,showTrayIcon,rememberWindowBounds,launchAtLogin,startHidden,reclaimWhenIdle,idleReclaimAfter,effects,hardwareAcceleration,systemNotifications);
}

@override
String toString() {
    return 'DesktopPreferences(closeAction: $closeAction, showTrayIcon: $showTrayIcon, rememberWindowBounds: $rememberWindowBounds, launchAtLogin: $launchAtLogin, startHidden: $startHidden, reclaimWhenIdle: $reclaimWhenIdle, idleReclaimAfter: $idleReclaimAfter, effects: $effects, hardwareAcceleration: $hardwareAcceleration, systemNotifications: $systemNotifications)';
}


}

/// @nodoc
abstract mixin class _$DesktopPreferencesCopyWith<$Res> implements $DesktopPreferencesCopyWith<$Res> {
  factory _$DesktopPreferencesCopyWith(_DesktopPreferences value, $Res Function(_DesktopPreferences) _then) = __$DesktopPreferencesCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _closeActionFromJson, toJson: _closeActionToJson) CloseAction closeAction, bool showTrayIcon, bool rememberWindowBounds, bool launchAtLogin, bool startHidden, bool reclaimWhenIdle, Duration idleReclaimAfter, bool effects, bool hardwareAcceleration, bool systemNotifications
});




}
/// @nodoc
class __$DesktopPreferencesCopyWithImpl<$Res>
    implements _$DesktopPreferencesCopyWith<$Res> {
  __$DesktopPreferencesCopyWithImpl(this._self, this._then);

  final _DesktopPreferences _self;
  final $Res Function(_DesktopPreferences) _then;

/// Create a copy of DesktopPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? closeAction = null,Object? showTrayIcon = null,Object? rememberWindowBounds = null,Object? launchAtLogin = null,Object? startHidden = null,Object? reclaimWhenIdle = null,Object? idleReclaimAfter = null,Object? effects = null,Object? hardwareAcceleration = null,Object? systemNotifications = null,}) {
  return _then(_DesktopPreferences(
closeAction: null == closeAction ? _self.closeAction : closeAction // ignore: cast_nullable_to_non_nullable
as CloseAction,showTrayIcon: null == showTrayIcon ? _self.showTrayIcon : showTrayIcon // ignore: cast_nullable_to_non_nullable
as bool,rememberWindowBounds: null == rememberWindowBounds ? _self.rememberWindowBounds : rememberWindowBounds // ignore: cast_nullable_to_non_nullable
as bool,launchAtLogin: null == launchAtLogin ? _self.launchAtLogin : launchAtLogin // ignore: cast_nullable_to_non_nullable
as bool,startHidden: null == startHidden ? _self.startHidden : startHidden // ignore: cast_nullable_to_non_nullable
as bool,reclaimWhenIdle: null == reclaimWhenIdle ? _self.reclaimWhenIdle : reclaimWhenIdle // ignore: cast_nullable_to_non_nullable
as bool,idleReclaimAfter: null == idleReclaimAfter ? _self.idleReclaimAfter : idleReclaimAfter // ignore: cast_nullable_to_non_nullable
as Duration,effects: null == effects ? _self.effects : effects // ignore: cast_nullable_to_non_nullable
as bool,hardwareAcceleration: null == hardwareAcceleration ? _self.hardwareAcceleration : hardwareAcceleration // ignore: cast_nullable_to_non_nullable
as bool,systemNotifications: null == systemNotifications ? _self.systemNotifications : systemNotifications // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
