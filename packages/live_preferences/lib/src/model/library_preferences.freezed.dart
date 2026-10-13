// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LibraryPreferences {

/// The layout of the live room lists.
 LiveListLayout get listLayout;/// How many columns the grid uses; ignored in list layout.
 int get gridColumns;/// How many watch history entries are kept, oldest evicted first.
 int get historyLimit;
/// Create a copy of LibraryPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryPreferencesCopyWith<LibraryPreferences> get copyWith => _$LibraryPreferencesCopyWithImpl<LibraryPreferences>(this as LibraryPreferences, _$identity);

  /// Serializes this LibraryPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LibraryPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryPreferences&&(identical(other.listLayout, _this.listLayout) || other.listLayout == _this.listLayout)&&(identical(other.gridColumns, _this.gridColumns) || other.gridColumns == _this.gridColumns)&&(identical(other.historyLimit, _this.historyLimit) || other.historyLimit == _this.historyLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LibraryPreferences;
  return Object.hash(runtimeType,_this.listLayout,_this.gridColumns,_this.historyLimit);
}

@override
String toString() {
  final _this = this as LibraryPreferences;
  return 'LibraryPreferences(listLayout: ${_this.listLayout}, gridColumns: ${_this.gridColumns}, historyLimit: ${_this.historyLimit})';
}


}

/// @nodoc
abstract mixin class $LibraryPreferencesCopyWith<$Res>  {
  factory $LibraryPreferencesCopyWith(LibraryPreferences value, $Res Function(LibraryPreferences) _then) = _$LibraryPreferencesCopyWithImpl;
@useResult
$Res call({
 LiveListLayout listLayout, int gridColumns, int historyLimit
});




}
/// @nodoc
class _$LibraryPreferencesCopyWithImpl<$Res>
    implements $LibraryPreferencesCopyWith<$Res> {
  _$LibraryPreferencesCopyWithImpl(this._self, this._then);

  final LibraryPreferences _self;
  final $Res Function(LibraryPreferences) _then;

/// Create a copy of LibraryPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? listLayout = null,Object? gridColumns = null,Object? historyLimit = null,}) {
  return _then(LibraryPreferences(
listLayout: null == listLayout ? _self.listLayout : listLayout // ignore: cast_nullable_to_non_nullable
as LiveListLayout,gridColumns: null == gridColumns ? _self.gridColumns : gridColumns // ignore: cast_nullable_to_non_nullable
as int,historyLimit: null == historyLimit ? _self.historyLimit : historyLimit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryPreferences].
extension LibraryPreferencesPatterns on LibraryPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryPreferences value)  $default,){
final _that = this;
switch (_that) {
case _LibraryPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveListLayout listLayout,  int gridColumns,  int historyLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryPreferences() when $default != null:
return $default(_that.listLayout,_that.gridColumns,_that.historyLimit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveListLayout listLayout,  int gridColumns,  int historyLimit)  $default,) {final _that = this;
switch (_that) {
case _LibraryPreferences():
return $default(_that.listLayout,_that.gridColumns,_that.historyLimit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveListLayout listLayout,  int gridColumns,  int historyLimit)?  $default,) {final _that = this;
switch (_that) {
case _LibraryPreferences() when $default != null:
return $default(_that.listLayout,_that.gridColumns,_that.historyLimit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibraryPreferences implements LibraryPreferences {
  const _LibraryPreferences({this.listLayout = LiveListLayout.grid, this.gridColumns = 2, this.historyLimit = 300});
  factory _LibraryPreferences.fromJson(Map<String, dynamic> json) => _$LibraryPreferencesFromJson(json);

/// The layout of the live room lists.
@override@JsonKey() final  LiveListLayout listLayout;
/// How many columns the grid uses; ignored in list layout.
@override@JsonKey() final  int gridColumns;
/// How many watch history entries are kept, oldest evicted first.
@override@JsonKey() final  int historyLimit;

/// Create a copy of LibraryPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryPreferencesCopyWith<_LibraryPreferences> get copyWith => __$LibraryPreferencesCopyWithImpl<_LibraryPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibraryPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryPreferences&&(identical(other.listLayout, listLayout) || other.listLayout == listLayout)&&(identical(other.gridColumns, gridColumns) || other.gridColumns == gridColumns)&&(identical(other.historyLimit, historyLimit) || other.historyLimit == historyLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,listLayout,gridColumns,historyLimit);
}

@override
String toString() {
    return 'LibraryPreferences(listLayout: $listLayout, gridColumns: $gridColumns, historyLimit: $historyLimit)';
}


}

/// @nodoc
abstract mixin class _$LibraryPreferencesCopyWith<$Res> implements $LibraryPreferencesCopyWith<$Res> {
  factory _$LibraryPreferencesCopyWith(_LibraryPreferences value, $Res Function(_LibraryPreferences) _then) = __$LibraryPreferencesCopyWithImpl;
@override @useResult
$Res call({
 LiveListLayout listLayout, int gridColumns, int historyLimit
});




}
/// @nodoc
class __$LibraryPreferencesCopyWithImpl<$Res>
    implements _$LibraryPreferencesCopyWith<$Res> {
  __$LibraryPreferencesCopyWithImpl(this._self, this._then);

  final _LibraryPreferences _self;
  final $Res Function(_LibraryPreferences) _then;

/// Create a copy of LibraryPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? listLayout = null,Object? gridColumns = null,Object? historyLimit = null,}) {
  return _then(_LibraryPreferences(
listLayout: null == listLayout ? _self.listLayout : listLayout // ignore: cast_nullable_to_non_nullable
as LiveListLayout,gridColumns: null == gridColumns ? _self.gridColumns : gridColumns // ignore: cast_nullable_to_non_nullable
as int,historyLimit: null == historyLimit ? _self.historyLimit : historyLimit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
