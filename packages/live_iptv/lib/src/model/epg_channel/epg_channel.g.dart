// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_channel.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<EpgChannel> _$epgChannelSerializer = _$EpgChannelSerializer();

class _$EpgChannelSerializer implements StructuredSerializer<EpgChannel> {
  @override
  final Iterable<Type> types = const [EpgChannel, _$EpgChannel];
  @override
  final String wireName = 'EpgChannel';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    EpgChannel object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'sourceId',
      serializers.serialize(
        object.sourceId,
        specifiedType: const FullType(String),
      ),
      'channelId',
      serializers.serialize(
        object.channelId,
        specifiedType: const FullType(String),
      ),
      'displayName',
      serializers.serialize(
        object.displayName,
        specifiedType: const FullType(String),
      ),
    ];
    Object? value;
    value = object.iconUrl;
    if (value != null) {
      result
        ..add('iconUrl')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  EpgChannel deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EpgChannelBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'sourceId':
          result.sourceId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'channelId':
          result.channelId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'displayName':
          result.displayName =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'iconUrl':
          result.iconUrl = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$EpgChannel extends EpgChannel {
  @override
  final String sourceId;
  @override
  final String channelId;
  @override
  final String displayName;
  @override
  final String? iconUrl;

  factory _$EpgChannel([void Function(EpgChannelBuilder)? updates]) =>
      (EpgChannelBuilder()..update(updates))._build();

  _$EpgChannel._({
    required this.sourceId,
    required this.channelId,
    required this.displayName,
    this.iconUrl,
  }) : super._();
  @override
  EpgChannel rebuild(void Function(EpgChannelBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EpgChannelBuilder toBuilder() => EpgChannelBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EpgChannel &&
        sourceId == other.sourceId &&
        channelId == other.channelId &&
        displayName == other.displayName &&
        iconUrl == other.iconUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, channelId.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, iconUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EpgChannel')
          ..add('sourceId', sourceId)
          ..add('channelId', channelId)
          ..add('displayName', displayName)
          ..add('iconUrl', iconUrl))
        .toString();
  }
}

class EpgChannelBuilder implements Builder<EpgChannel, EpgChannelBuilder> {
  _$EpgChannel? _$v;

  String? _sourceId;
  String? get sourceId => _$this._sourceId;
  set sourceId(String? sourceId) => _$this._sourceId = sourceId;

  String? _channelId;
  String? get channelId => _$this._channelId;
  set channelId(String? channelId) => _$this._channelId = channelId;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _iconUrl;
  String? get iconUrl => _$this._iconUrl;
  set iconUrl(String? iconUrl) => _$this._iconUrl = iconUrl;

  EpgChannelBuilder() {
    EpgChannel._initialize(this);
  }

  EpgChannelBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _sourceId = $v.sourceId;
      _channelId = $v.channelId;
      _displayName = $v.displayName;
      _iconUrl = $v.iconUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EpgChannel other) {
    _$v = other as _$EpgChannel;
  }

  @override
  void update(void Function(EpgChannelBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EpgChannel build() => _build();

  _$EpgChannel _build() {
    final _$result =
        _$v ??
        _$EpgChannel._(
          sourceId: BuiltValueNullFieldError.checkNotNull(
            sourceId,
            r'EpgChannel',
            'sourceId',
          ),
          channelId: BuiltValueNullFieldError.checkNotNull(
            channelId,
            r'EpgChannel',
            'channelId',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'EpgChannel',
            'displayName',
          ),
          iconUrl: iconUrl,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
