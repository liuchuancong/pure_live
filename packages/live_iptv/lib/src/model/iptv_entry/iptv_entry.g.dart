// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_entry.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<IptvEntry> _$iptvEntrySerializer = _$IptvEntrySerializer();

class _$IptvEntrySerializer implements StructuredSerializer<IptvEntry> {
  @override
  final Iterable<Type> types = const [IptvEntry, _$IptvEntry];
  @override
  final String wireName = 'IptvEntry';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    IptvEntry object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'url',
      serializers.serialize(object.url, specifiedType: const FullType(String)),
      'headers',
      serializers.serialize(
        object.headers,
        specifiedType: const FullType(BuiltMap, const [
          const FullType(String),
          const FullType(String),
        ]),
      ),
      'alternatives',
      serializers.serialize(
        object.alternatives,
        specifiedType: const FullType(BuiltList, const [
          const FullType(String),
        ]),
      ),
    ];
    Object? value;
    value = object.group;
    if (value != null) {
      result
        ..add('group')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.tvgId;
    if (value != null) {
      result
        ..add('tvgId')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.tvgLogo;
    if (value != null) {
      result
        ..add('tvgLogo')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.channelNumber;
    if (value != null) {
      result
        ..add('channelNumber')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.catchupSource;
    if (value != null) {
      result
        ..add('catchupSource')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.catchupMode;
    if (value != null) {
      result
        ..add('catchupMode')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.catchupDays;
    if (value != null) {
      result
        ..add('catchupDays')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  IptvEntry deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IptvEntryBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'name':
          result.name =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'url':
          result.url =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'group':
          result.group = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'tvgId':
          result.tvgId = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'tvgLogo':
          result.tvgLogo = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'channelNumber':
          result.channelNumber = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'headers':
          result.headers.replace(
            serializers.deserialize(
              value,
              specifiedType: const FullType(BuiltMap, const [
                const FullType(String),
                const FullType(String),
              ]),
            )!,
          );
          break;
        case 'alternatives':
          result.alternatives.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(String),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'catchupSource':
          result.catchupSource = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'catchupMode':
          result.catchupMode = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'catchupDays':
          result.catchupDays = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$IptvEntry extends IptvEntry {
  @override
  final String name;
  @override
  final String url;
  @override
  final String? group;
  @override
  final String? tvgId;
  @override
  final String? tvgLogo;
  @override
  final int? channelNumber;
  @override
  final BuiltMap<String, String> headers;
  @override
  final BuiltList<String> alternatives;
  @override
  final String? catchupSource;
  @override
  final String? catchupMode;
  @override
  final String? catchupDays;

  factory _$IptvEntry([void Function(IptvEntryBuilder)? updates]) =>
      (IptvEntryBuilder()..update(updates))._build();

  _$IptvEntry._({
    required this.name,
    required this.url,
    this.group,
    this.tvgId,
    this.tvgLogo,
    this.channelNumber,
    required this.headers,
    required this.alternatives,
    this.catchupSource,
    this.catchupMode,
    this.catchupDays,
  }) : super._();
  @override
  IptvEntry rebuild(void Function(IptvEntryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IptvEntryBuilder toBuilder() => IptvEntryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IptvEntry &&
        name == other.name &&
        url == other.url &&
        group == other.group &&
        tvgId == other.tvgId &&
        tvgLogo == other.tvgLogo &&
        channelNumber == other.channelNumber &&
        headers == other.headers &&
        alternatives == other.alternatives &&
        catchupSource == other.catchupSource &&
        catchupMode == other.catchupMode &&
        catchupDays == other.catchupDays;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, group.hashCode);
    _$hash = $jc(_$hash, tvgId.hashCode);
    _$hash = $jc(_$hash, tvgLogo.hashCode);
    _$hash = $jc(_$hash, channelNumber.hashCode);
    _$hash = $jc(_$hash, headers.hashCode);
    _$hash = $jc(_$hash, alternatives.hashCode);
    _$hash = $jc(_$hash, catchupSource.hashCode);
    _$hash = $jc(_$hash, catchupMode.hashCode);
    _$hash = $jc(_$hash, catchupDays.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IptvEntry')
          ..add('name', name)
          ..add('url', url)
          ..add('group', group)
          ..add('tvgId', tvgId)
          ..add('tvgLogo', tvgLogo)
          ..add('channelNumber', channelNumber)
          ..add('headers', headers)
          ..add('alternatives', alternatives)
          ..add('catchupSource', catchupSource)
          ..add('catchupMode', catchupMode)
          ..add('catchupDays', catchupDays))
        .toString();
  }
}

class IptvEntryBuilder implements Builder<IptvEntry, IptvEntryBuilder> {
  _$IptvEntry? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  String? _group;
  String? get group => _$this._group;
  set group(String? group) => _$this._group = group;

  String? _tvgId;
  String? get tvgId => _$this._tvgId;
  set tvgId(String? tvgId) => _$this._tvgId = tvgId;

  String? _tvgLogo;
  String? get tvgLogo => _$this._tvgLogo;
  set tvgLogo(String? tvgLogo) => _$this._tvgLogo = tvgLogo;

  int? _channelNumber;
  int? get channelNumber => _$this._channelNumber;
  set channelNumber(int? channelNumber) =>
      _$this._channelNumber = channelNumber;

  MapBuilder<String, String>? _headers;
  MapBuilder<String, String> get headers =>
      _$this._headers ??= MapBuilder<String, String>();
  set headers(MapBuilder<String, String>? headers) => _$this._headers = headers;

  ListBuilder<String>? _alternatives;
  ListBuilder<String> get alternatives =>
      _$this._alternatives ??= ListBuilder<String>();
  set alternatives(ListBuilder<String>? alternatives) =>
      _$this._alternatives = alternatives;

  String? _catchupSource;
  String? get catchupSource => _$this._catchupSource;
  set catchupSource(String? catchupSource) =>
      _$this._catchupSource = catchupSource;

  String? _catchupMode;
  String? get catchupMode => _$this._catchupMode;
  set catchupMode(String? catchupMode) => _$this._catchupMode = catchupMode;

  String? _catchupDays;
  String? get catchupDays => _$this._catchupDays;
  set catchupDays(String? catchupDays) => _$this._catchupDays = catchupDays;

  IptvEntryBuilder() {
    IptvEntry._initialize(this);
  }

  IptvEntryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _url = $v.url;
      _group = $v.group;
      _tvgId = $v.tvgId;
      _tvgLogo = $v.tvgLogo;
      _channelNumber = $v.channelNumber;
      _headers = $v.headers.toBuilder();
      _alternatives = $v.alternatives.toBuilder();
      _catchupSource = $v.catchupSource;
      _catchupMode = $v.catchupMode;
      _catchupDays = $v.catchupDays;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IptvEntry other) {
    _$v = other as _$IptvEntry;
  }

  @override
  void update(void Function(IptvEntryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IptvEntry build() => _build();

  _$IptvEntry _build() {
    _$IptvEntry _$result;
    try {
      _$result =
          _$v ??
          _$IptvEntry._(
            name: BuiltValueNullFieldError.checkNotNull(
              name,
              r'IptvEntry',
              'name',
            ),
            url: BuiltValueNullFieldError.checkNotNull(
              url,
              r'IptvEntry',
              'url',
            ),
            group: group,
            tvgId: tvgId,
            tvgLogo: tvgLogo,
            channelNumber: channelNumber,
            headers: headers.build(),
            alternatives: alternatives.build(),
            catchupSource: catchupSource,
            catchupMode: catchupMode,
            catchupDays: catchupDays,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'headers';
        headers.build();
        _$failedField = 'alternatives';
        alternatives.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'IptvEntry',
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
