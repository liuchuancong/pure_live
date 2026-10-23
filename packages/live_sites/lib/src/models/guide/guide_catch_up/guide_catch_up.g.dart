// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_catch_up.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<GuideCatchUp> _$guideCatchUpSerializer = _$GuideCatchUpSerializer();

class _$GuideCatchUpSerializer implements StructuredSerializer<GuideCatchUp> {
  @override
  final Iterable<Type> types = const [GuideCatchUp, _$GuideCatchUp];
  @override
  final String wireName = 'GuideCatchUp';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    GuideCatchUp object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'active',
      serializers.serialize(object.active, specifiedType: const FullType(bool)),
    ];
    Object? value;
    value = object.url;
    if (value != null) {
      result
        ..add('url')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.start;
    if (value != null) {
      result
        ..add('start')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.end;
    if (value != null) {
      result
        ..add('end')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.mode;
    if (value != null) {
      result
        ..add('mode')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.urlTemplate;
    if (value != null) {
      result
        ..add('urlTemplate')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.windowDays;
    if (value != null) {
      result
        ..add('windowDays')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(double)),
        );
    }
    value = object.correctionHours;
    if (value != null) {
      result
        ..add('correctionHours')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(double)),
        );
    }
    value = object.catchupId;
    if (value != null) {
      result
        ..add('catchupId')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  GuideCatchUp deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GuideCatchUpBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'url':
          result.url = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'active':
          result.active =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'start':
          result.start = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'end':
          result.end = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'mode':
          result.mode = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'urlTemplate':
          result.urlTemplate = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'windowDays':
          result.windowDays = serializers.deserialize(
            value,
            specifiedType: const FullType(double),
          ) as double?;
          break;
        case 'correctionHours':
          result.correctionHours = serializers.deserialize(
            value,
            specifiedType: const FullType(double),
          ) as double?;
          break;
        case 'catchupId':
          result.catchupId = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$GuideCatchUp extends GuideCatchUp {
  @override
  final String? url;
  @override
  final bool active;
  @override
  final int? start;
  @override
  final int? end;
  @override
  final String? mode;
  @override
  final String? urlTemplate;
  @override
  final double? windowDays;
  @override
  final double? correctionHours;
  @override
  final String? catchupId;

  factory _$GuideCatchUp([void Function(GuideCatchUpBuilder)? updates]) =>
      (GuideCatchUpBuilder()..update(updates))._build();

  _$GuideCatchUp._({
    this.url,
    required this.active,
    this.start,
    this.end,
    this.mode,
    this.urlTemplate,
    this.windowDays,
    this.correctionHours,
    this.catchupId,
  }) : super._();
  @override
  GuideCatchUp rebuild(void Function(GuideCatchUpBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GuideCatchUpBuilder toBuilder() => GuideCatchUpBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GuideCatchUp &&
        url == other.url &&
        active == other.active &&
        start == other.start &&
        end == other.end &&
        mode == other.mode &&
        urlTemplate == other.urlTemplate &&
        windowDays == other.windowDays &&
        correctionHours == other.correctionHours &&
        catchupId == other.catchupId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, active.hashCode);
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jc(_$hash, end.hashCode);
    _$hash = $jc(_$hash, mode.hashCode);
    _$hash = $jc(_$hash, urlTemplate.hashCode);
    _$hash = $jc(_$hash, windowDays.hashCode);
    _$hash = $jc(_$hash, correctionHours.hashCode);
    _$hash = $jc(_$hash, catchupId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GuideCatchUp')
          ..add('url', url)
          ..add('active', active)
          ..add('start', start)
          ..add('end', end)
          ..add('mode', mode)
          ..add('urlTemplate', urlTemplate)
          ..add('windowDays', windowDays)
          ..add('correctionHours', correctionHours)
          ..add('catchupId', catchupId))
        .toString();
  }
}

class GuideCatchUpBuilder
    implements Builder<GuideCatchUp, GuideCatchUpBuilder> {
  _$GuideCatchUp? _$v;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  bool? _active;
  bool? get active => _$this._active;
  set active(bool? active) => _$this._active = active;

  int? _start;
  int? get start => _$this._start;
  set start(int? start) => _$this._start = start;

  int? _end;
  int? get end => _$this._end;
  set end(int? end) => _$this._end = end;

  String? _mode;
  String? get mode => _$this._mode;
  set mode(String? mode) => _$this._mode = mode;

  String? _urlTemplate;
  String? get urlTemplate => _$this._urlTemplate;
  set urlTemplate(String? urlTemplate) => _$this._urlTemplate = urlTemplate;

  double? _windowDays;
  double? get windowDays => _$this._windowDays;
  set windowDays(double? windowDays) => _$this._windowDays = windowDays;

  double? _correctionHours;
  double? get correctionHours => _$this._correctionHours;
  set correctionHours(double? correctionHours) =>
      _$this._correctionHours = correctionHours;

  String? _catchupId;
  String? get catchupId => _$this._catchupId;
  set catchupId(String? catchupId) => _$this._catchupId = catchupId;

  GuideCatchUpBuilder() {
    GuideCatchUp._initialize(this);
  }

  GuideCatchUpBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _url = $v.url;
      _active = $v.active;
      _start = $v.start;
      _end = $v.end;
      _mode = $v.mode;
      _urlTemplate = $v.urlTemplate;
      _windowDays = $v.windowDays;
      _correctionHours = $v.correctionHours;
      _catchupId = $v.catchupId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GuideCatchUp other) {
    _$v = other as _$GuideCatchUp;
  }

  @override
  void update(void Function(GuideCatchUpBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GuideCatchUp build() => _build();

  _$GuideCatchUp _build() {
    final _$result =
        _$v ??
        _$GuideCatchUp._(
          url: url,
          active: BuiltValueNullFieldError.checkNotNull(
            active,
            r'GuideCatchUp',
            'active',
          ),
          start: start,
          end: end,
          mode: mode,
          urlTemplate: urlTemplate,
          windowDays: windowDays,
          correctionHours: correctionHours,
          catchupId: catchupId,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
