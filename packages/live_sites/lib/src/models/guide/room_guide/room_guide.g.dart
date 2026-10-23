// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_guide.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RoomGuide> _$roomGuideSerializer = _$RoomGuideSerializer();

class _$RoomGuideSerializer implements StructuredSerializer<RoomGuide> {
  @override
  final Iterable<Type> types = const [RoomGuide, _$RoomGuide];
  @override
  final String wireName = 'RoomGuide';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RoomGuide object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'currentProgramme',
      serializers.serialize(object.currentProgramme, specifiedType: const FullType(String)),
      'catchUp',
      serializers.serialize(object.catchUp, specifiedType: const FullType(GuideCatchUp)),
      'httpHeaders',
      serializers.serialize(
        object.httpHeaders,
        specifiedType: const FullType(BuiltMap, const [const FullType(String), const FullType(String)]),
      ),
    ];
    Object? value;
    value = object.epgId;
    if (value != null) {
      result
        ..add('epgId')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.currentProgrammeDescription;
    if (value != null) {
      result
        ..add('currentProgrammeDescription')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  RoomGuide deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RoomGuideBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'epgId':
          result.epgId = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'currentProgramme':
          result.currentProgramme = serializers.deserialize(value, specifiedType: const FullType(String))! as String;
          break;
        case 'currentProgrammeDescription':
          result.currentProgrammeDescription =
              serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'catchUp':
          result.catchUp.replace(
            serializers.deserialize(value, specifiedType: const FullType(GuideCatchUp))! as GuideCatchUp,
          );
          break;
        case 'httpHeaders':
          result.httpHeaders.replace(
            serializers.deserialize(
              value,
              specifiedType: const FullType(BuiltMap, const [const FullType(String), const FullType(String)]),
            )!,
          );
          break;
      }
    }

    return result.build();
  }
}

class _$RoomGuide extends RoomGuide {
  @override
  final String? epgId;
  @override
  final String currentProgramme;
  @override
  final String? currentProgrammeDescription;
  @override
  final GuideCatchUp catchUp;
  @override
  final BuiltMap<String, String> httpHeaders;

  factory _$RoomGuide([void Function(RoomGuideBuilder)? updates]) => (RoomGuideBuilder()..update(updates))._build();

  _$RoomGuide._({
    this.epgId,
    required this.currentProgramme,
    this.currentProgrammeDescription,
    required this.catchUp,
    required this.httpHeaders,
  }) : super._();
  @override
  RoomGuide rebuild(void Function(RoomGuideBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  RoomGuideBuilder toBuilder() => RoomGuideBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomGuide &&
        epgId == other.epgId &&
        currentProgramme == other.currentProgramme &&
        currentProgrammeDescription == other.currentProgrammeDescription &&
        catchUp == other.catchUp &&
        httpHeaders == other.httpHeaders;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, epgId.hashCode);
    _$hash = $jc(_$hash, currentProgramme.hashCode);
    _$hash = $jc(_$hash, currentProgrammeDescription.hashCode);
    _$hash = $jc(_$hash, catchUp.hashCode);
    _$hash = $jc(_$hash, httpHeaders.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomGuide')
          ..add('epgId', epgId)
          ..add('currentProgramme', currentProgramme)
          ..add('currentProgrammeDescription', currentProgrammeDescription)
          ..add('catchUp', catchUp)
          ..add('httpHeaders', httpHeaders))
        .toString();
  }
}

class RoomGuideBuilder implements Builder<RoomGuide, RoomGuideBuilder> {
  _$RoomGuide? _$v;

  String? _epgId;
  String? get epgId => _$this._epgId;
  set epgId(String? epgId) => _$this._epgId = epgId;

  String? _currentProgramme;
  String? get currentProgramme => _$this._currentProgramme;
  set currentProgramme(String? currentProgramme) => _$this._currentProgramme = currentProgramme;

  String? _currentProgrammeDescription;
  String? get currentProgrammeDescription => _$this._currentProgrammeDescription;
  set currentProgrammeDescription(String? currentProgrammeDescription) =>
      _$this._currentProgrammeDescription = currentProgrammeDescription;

  GuideCatchUpBuilder? _catchUp;
  GuideCatchUpBuilder get catchUp => _$this._catchUp ??= GuideCatchUpBuilder();
  set catchUp(GuideCatchUpBuilder? catchUp) => _$this._catchUp = catchUp;

  MapBuilder<String, String>? _httpHeaders;
  MapBuilder<String, String> get httpHeaders => _$this._httpHeaders ??= MapBuilder<String, String>();
  set httpHeaders(MapBuilder<String, String>? httpHeaders) => _$this._httpHeaders = httpHeaders;

  RoomGuideBuilder() {
    RoomGuide._initialize(this);
  }

  RoomGuideBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _epgId = $v.epgId;
      _currentProgramme = $v.currentProgramme;
      _currentProgrammeDescription = $v.currentProgrammeDescription;
      _catchUp = $v.catchUp.toBuilder();
      _httpHeaders = $v.httpHeaders.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomGuide other) {
    _$v = other as _$RoomGuide;
  }

  @override
  void update(void Function(RoomGuideBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomGuide build() => _build();

  _$RoomGuide _build() {
    _$RoomGuide _$result;
    try {
      _$result =
          _$v ??
          _$RoomGuide._(
            epgId: epgId,
            currentProgramme: BuiltValueNullFieldError.checkNotNull(currentProgramme, r'RoomGuide', 'currentProgramme'),
            currentProgrammeDescription: currentProgrammeDescription,
            catchUp: catchUp.build(),
            httpHeaders: httpHeaders.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'catchUp';
        catchUp.build();
        _$failedField = 'httpHeaders';
        httpHeaders.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'RoomGuide', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
