// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_channel.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GuideChannel extends GuideChannel {
  @override
  final String id;
  @override
  final BuiltList<String> displayNames;
  @override
  final String? iconUrl;

  factory _$GuideChannel([void Function(GuideChannelBuilder)? updates]) =>
      (GuideChannelBuilder()..update(updates))._build();

  _$GuideChannel._({required this.id, required this.displayNames, this.iconUrl})
    : super._();
  @override
  GuideChannel rebuild(void Function(GuideChannelBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GuideChannelBuilder toBuilder() => GuideChannelBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GuideChannel &&
        id == other.id &&
        displayNames == other.displayNames &&
        iconUrl == other.iconUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, displayNames.hashCode);
    _$hash = $jc(_$hash, iconUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GuideChannel')
          ..add('id', id)
          ..add('displayNames', displayNames)
          ..add('iconUrl', iconUrl))
        .toString();
  }
}

class GuideChannelBuilder
    implements Builder<GuideChannel, GuideChannelBuilder> {
  _$GuideChannel? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  ListBuilder<String>? _displayNames;
  ListBuilder<String> get displayNames =>
      _$this._displayNames ??= ListBuilder<String>();
  set displayNames(ListBuilder<String>? displayNames) =>
      _$this._displayNames = displayNames;

  String? _iconUrl;
  String? get iconUrl => _$this._iconUrl;
  set iconUrl(String? iconUrl) => _$this._iconUrl = iconUrl;

  GuideChannelBuilder() {
    GuideChannel._initialize(this);
  }

  GuideChannelBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _displayNames = $v.displayNames.toBuilder();
      _iconUrl = $v.iconUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GuideChannel other) {
    _$v = other as _$GuideChannel;
  }

  @override
  void update(void Function(GuideChannelBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GuideChannel build() => _build();

  _$GuideChannel _build() {
    _$GuideChannel _$result;
    try {
      _$result =
          _$v ??
          _$GuideChannel._(
            id: BuiltValueNullFieldError.checkNotNull(
              id,
              r'GuideChannel',
              'id',
            ),
            displayNames: displayNames.build(),
            iconUrl: iconUrl,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'displayNames';
        displayNames.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GuideChannel',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
