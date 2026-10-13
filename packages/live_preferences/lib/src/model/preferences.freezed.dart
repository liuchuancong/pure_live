// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Preferences {

/// Playback: quality, engine, line, recovery.
 PlaybackPreferences get playback;/// Danmaku: on/off, opacity, size, display area.
 DanmakuPreferences get danmaku;/// Library: list layout and history bounds.
 LibraryPreferences get library;/// TV navigation: focus behaviour.
 TvPreferences get tv;/// Floating window behaviour.
 WindowPreferences get window;/// Appearance: design language, theme mode, accent.
 AppearancePreferences get appearance;/// IPTV: how the channel library and its guides go stale.
 IptvPreferences get iptv;/// Desktop shell: close button, tray, sign-in, rendering fallbacks.
 DesktopPreferences get desktop;
/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PreferencesCopyWith<Preferences> get copyWith => _$PreferencesCopyWithImpl<Preferences>(this as Preferences, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Preferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Preferences&&(identical(other.playback, _this.playback) || other.playback == _this.playback)&&(identical(other.danmaku, _this.danmaku) || other.danmaku == _this.danmaku)&&(identical(other.library, _this.library) || other.library == _this.library)&&(identical(other.tv, _this.tv) || other.tv == _this.tv)&&(identical(other.window, _this.window) || other.window == _this.window)&&(identical(other.appearance, _this.appearance) || other.appearance == _this.appearance)&&(identical(other.iptv, _this.iptv) || other.iptv == _this.iptv)&&(identical(other.desktop, _this.desktop) || other.desktop == _this.desktop));
}


@override
int get hashCode {
  final _this = this as Preferences;
  return Object.hash(runtimeType,_this.playback,_this.danmaku,_this.library,_this.tv,_this.window,_this.appearance,_this.iptv,_this.desktop);
}

@override
String toString() {
  final _this = this as Preferences;
  return 'Preferences(playback: ${_this.playback}, danmaku: ${_this.danmaku}, library: ${_this.library}, tv: ${_this.tv}, window: ${_this.window}, appearance: ${_this.appearance}, iptv: ${_this.iptv}, desktop: ${_this.desktop})';
}


}

/// @nodoc
abstract mixin class $PreferencesCopyWith<$Res>  {
  factory $PreferencesCopyWith(Preferences value, $Res Function(Preferences) _then) = _$PreferencesCopyWithImpl;
@useResult
$Res call({
 PlaybackPreferences playback, DanmakuPreferences danmaku, LibraryPreferences library, TvPreferences tv, WindowPreferences window, AppearancePreferences appearance, IptvPreferences iptv, DesktopPreferences desktop
});


$PlaybackPreferencesCopyWith<$Res> get playback;$DanmakuPreferencesCopyWith<$Res> get danmaku;$LibraryPreferencesCopyWith<$Res> get library;$TvPreferencesCopyWith<$Res> get tv;$WindowPreferencesCopyWith<$Res> get window;$AppearancePreferencesCopyWith<$Res> get appearance;$IptvPreferencesCopyWith<$Res> get iptv;$DesktopPreferencesCopyWith<$Res> get desktop;

}
/// @nodoc
class _$PreferencesCopyWithImpl<$Res>
    implements $PreferencesCopyWith<$Res> {
  _$PreferencesCopyWithImpl(this._self, this._then);

  final Preferences _self;
  final $Res Function(Preferences) _then;

/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? playback = null,Object? danmaku = null,Object? library = null,Object? tv = null,Object? window = null,Object? appearance = null,Object? iptv = null,Object? desktop = null,}) {
  return _then(Preferences(
playback: null == playback ? _self.playback : playback // ignore: cast_nullable_to_non_nullable
as PlaybackPreferences,danmaku: null == danmaku ? _self.danmaku : danmaku // ignore: cast_nullable_to_non_nullable
as DanmakuPreferences,library: null == library ? _self.library : library // ignore: cast_nullable_to_non_nullable
as LibraryPreferences,tv: null == tv ? _self.tv : tv // ignore: cast_nullable_to_non_nullable
as TvPreferences,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as WindowPreferences,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as AppearancePreferences,iptv: null == iptv ? _self.iptv : iptv // ignore: cast_nullable_to_non_nullable
as IptvPreferences,desktop: null == desktop ? _self.desktop : desktop // ignore: cast_nullable_to_non_nullable
as DesktopPreferences,
  ));
}
/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackPreferencesCopyWith<$Res> get playback {
  
  return $PlaybackPreferencesCopyWith<$Res>(_self.playback, (value) {
    return _then(_self.copyWith(playback: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DanmakuPreferencesCopyWith<$Res> get danmaku {
  
  return $DanmakuPreferencesCopyWith<$Res>(_self.danmaku, (value) {
    return _then(_self.copyWith(danmaku: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibraryPreferencesCopyWith<$Res> get library {
  
  return $LibraryPreferencesCopyWith<$Res>(_self.library, (value) {
    return _then(_self.copyWith(library: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvPreferencesCopyWith<$Res> get tv {
  
  return $TvPreferencesCopyWith<$Res>(_self.tv, (value) {
    return _then(_self.copyWith(tv: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPreferencesCopyWith<$Res> get window {
  
  return $WindowPreferencesCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppearancePreferencesCopyWith<$Res> get appearance {
  
  return $AppearancePreferencesCopyWith<$Res>(_self.appearance, (value) {
    return _then(_self.copyWith(appearance: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IptvPreferencesCopyWith<$Res> get iptv {
  
  return $IptvPreferencesCopyWith<$Res>(_self.iptv, (value) {
    return _then(_self.copyWith(iptv: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesktopPreferencesCopyWith<$Res> get desktop {
  
  return $DesktopPreferencesCopyWith<$Res>(_self.desktop, (value) {
    return _then(_self.copyWith(desktop: value));
  });
}
}


/// Adds pattern-matching-related methods to [Preferences].
extension PreferencesPatterns on Preferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Preferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Preferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Preferences value)  $default,){
final _that = this;
switch (_that) {
case _Preferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Preferences value)?  $default,){
final _that = this;
switch (_that) {
case _Preferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlaybackPreferences playback,  DanmakuPreferences danmaku,  LibraryPreferences library,  TvPreferences tv,  WindowPreferences window,  AppearancePreferences appearance,  IptvPreferences iptv,  DesktopPreferences desktop)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Preferences() when $default != null:
return $default(_that.playback,_that.danmaku,_that.library,_that.tv,_that.window,_that.appearance,_that.iptv,_that.desktop);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlaybackPreferences playback,  DanmakuPreferences danmaku,  LibraryPreferences library,  TvPreferences tv,  WindowPreferences window,  AppearancePreferences appearance,  IptvPreferences iptv,  DesktopPreferences desktop)  $default,) {final _that = this;
switch (_that) {
case _Preferences():
return $default(_that.playback,_that.danmaku,_that.library,_that.tv,_that.window,_that.appearance,_that.iptv,_that.desktop);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlaybackPreferences playback,  DanmakuPreferences danmaku,  LibraryPreferences library,  TvPreferences tv,  WindowPreferences window,  AppearancePreferences appearance,  IptvPreferences iptv,  DesktopPreferences desktop)?  $default,) {final _that = this;
switch (_that) {
case _Preferences() when $default != null:
return $default(_that.playback,_that.danmaku,_that.library,_that.tv,_that.window,_that.appearance,_that.iptv,_that.desktop);case _:
  return null;

}
}

}

/// @nodoc


class _Preferences implements Preferences {
  const _Preferences({this.playback = const PlaybackPreferences(), this.danmaku = const DanmakuPreferences(), this.library = const LibraryPreferences(), this.tv = const TvPreferences(), this.window = const WindowPreferences(), this.appearance = const AppearancePreferences(), this.iptv = const IptvPreferences(), this.desktop = const DesktopPreferences()});
  

/// Playback: quality, engine, line, recovery.
@override@JsonKey() final  PlaybackPreferences playback;
/// Danmaku: on/off, opacity, size, display area.
@override@JsonKey() final  DanmakuPreferences danmaku;
/// Library: list layout and history bounds.
@override@JsonKey() final  LibraryPreferences library;
/// TV navigation: focus behaviour.
@override@JsonKey() final  TvPreferences tv;
/// Floating window behaviour.
@override@JsonKey() final  WindowPreferences window;
/// Appearance: design language, theme mode, accent.
@override@JsonKey() final  AppearancePreferences appearance;
/// IPTV: how the channel library and its guides go stale.
@override@JsonKey() final  IptvPreferences iptv;
/// Desktop shell: close button, tray, sign-in, rendering fallbacks.
@override@JsonKey() final  DesktopPreferences desktop;

/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreferencesCopyWith<_Preferences> get copyWith => __$PreferencesCopyWithImpl<_Preferences>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Preferences&&(identical(other.playback, playback) || other.playback == playback)&&(identical(other.danmaku, danmaku) || other.danmaku == danmaku)&&(identical(other.library, library) || other.library == library)&&(identical(other.tv, tv) || other.tv == tv)&&(identical(other.window, window) || other.window == window)&&(identical(other.appearance, appearance) || other.appearance == appearance)&&(identical(other.iptv, iptv) || other.iptv == iptv)&&(identical(other.desktop, desktop) || other.desktop == desktop));
}


@override
int get hashCode {
    return Object.hash(runtimeType,playback,danmaku,library,tv,window,appearance,iptv,desktop);
}

@override
String toString() {
    return 'Preferences(playback: $playback, danmaku: $danmaku, library: $library, tv: $tv, window: $window, appearance: $appearance, iptv: $iptv, desktop: $desktop)';
}


}

/// @nodoc
abstract mixin class _$PreferencesCopyWith<$Res> implements $PreferencesCopyWith<$Res> {
  factory _$PreferencesCopyWith(_Preferences value, $Res Function(_Preferences) _then) = __$PreferencesCopyWithImpl;
@override @useResult
$Res call({
 PlaybackPreferences playback, DanmakuPreferences danmaku, LibraryPreferences library, TvPreferences tv, WindowPreferences window, AppearancePreferences appearance, IptvPreferences iptv, DesktopPreferences desktop
});


@override $PlaybackPreferencesCopyWith<$Res> get playback;@override $DanmakuPreferencesCopyWith<$Res> get danmaku;@override $LibraryPreferencesCopyWith<$Res> get library;@override $TvPreferencesCopyWith<$Res> get tv;@override $WindowPreferencesCopyWith<$Res> get window;@override $AppearancePreferencesCopyWith<$Res> get appearance;@override $IptvPreferencesCopyWith<$Res> get iptv;@override $DesktopPreferencesCopyWith<$Res> get desktop;

}
/// @nodoc
class __$PreferencesCopyWithImpl<$Res>
    implements _$PreferencesCopyWith<$Res> {
  __$PreferencesCopyWithImpl(this._self, this._then);

  final _Preferences _self;
  final $Res Function(_Preferences) _then;

/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playback = null,Object? danmaku = null,Object? library = null,Object? tv = null,Object? window = null,Object? appearance = null,Object? iptv = null,Object? desktop = null,}) {
  return _then(_Preferences(
playback: null == playback ? _self.playback : playback // ignore: cast_nullable_to_non_nullable
as PlaybackPreferences,danmaku: null == danmaku ? _self.danmaku : danmaku // ignore: cast_nullable_to_non_nullable
as DanmakuPreferences,library: null == library ? _self.library : library // ignore: cast_nullable_to_non_nullable
as LibraryPreferences,tv: null == tv ? _self.tv : tv // ignore: cast_nullable_to_non_nullable
as TvPreferences,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as WindowPreferences,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as AppearancePreferences,iptv: null == iptv ? _self.iptv : iptv // ignore: cast_nullable_to_non_nullable
as IptvPreferences,desktop: null == desktop ? _self.desktop : desktop // ignore: cast_nullable_to_non_nullable
as DesktopPreferences,
  ));
}

/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaybackPreferencesCopyWith<$Res> get playback {
  
  return $PlaybackPreferencesCopyWith<$Res>(_self.playback, (value) {
    return _then(_self.copyWith(playback: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DanmakuPreferencesCopyWith<$Res> get danmaku {
  
  return $DanmakuPreferencesCopyWith<$Res>(_self.danmaku, (value) {
    return _then(_self.copyWith(danmaku: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibraryPreferencesCopyWith<$Res> get library {
  
  return $LibraryPreferencesCopyWith<$Res>(_self.library, (value) {
    return _then(_self.copyWith(library: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvPreferencesCopyWith<$Res> get tv {
  
  return $TvPreferencesCopyWith<$Res>(_self.tv, (value) {
    return _then(_self.copyWith(tv: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindowPreferencesCopyWith<$Res> get window {
  
  return $WindowPreferencesCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppearancePreferencesCopyWith<$Res> get appearance {
  
  return $AppearancePreferencesCopyWith<$Res>(_self.appearance, (value) {
    return _then(_self.copyWith(appearance: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$IptvPreferencesCopyWith<$Res> get iptv {
  
  return $IptvPreferencesCopyWith<$Res>(_self.iptv, (value) {
    return _then(_self.copyWith(iptv: value));
  });
}/// Create a copy of Preferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesktopPreferencesCopyWith<$Res> get desktop {
  
  return $DesktopPreferencesCopyWith<$Res>(_self.desktop, (value) {
    return _then(_self.copyWith(desktop: value));
  });
}
}

// dart format on
