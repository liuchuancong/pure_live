// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_programme.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<EpgProgramme> _$epgProgrammeSerializer = _$EpgProgrammeSerializer();

class _$EpgProgrammeSerializer implements StructuredSerializer<EpgProgramme> {
  @override
  final Iterable<Type> types = const [EpgProgramme, _$EpgProgramme];
  @override
  final String wireName = 'EpgProgramme';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    EpgProgramme object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'channelId',
      serializers.serialize(
        object.channelId,
        specifiedType: const FullType(String),
      ),
      'start',
      serializers.serialize(
        object.start,
        specifiedType: const FullType(DateTime),
      ),
      'stop',
      serializers.serialize(
        object.stop,
        specifiedType: const FullType(DateTime),
      ),
      'sourceId',
      serializers.serialize(
        object.sourceId,
        specifiedType: const FullType(String),
      ),
      'title',
      serializers.serialize(
        object.title,
        specifiedType: const FullType(String),
      ),
    ];
    Object? value;
    value = object.subtitle;
    if (value != null) {
      result
        ..add('subtitle')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.description;
    if (value != null) {
      result
        ..add('description')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.category;
    if (value != null) {
      result
        ..add('category')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.episodeNum;
    if (value != null) {
      result
        ..add('episodeNum')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
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
  EpgProgramme deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EpgProgrammeBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'channelId':
          result.channelId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'start':
          result.start =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )!
                  as DateTime;
          break;
        case 'stop':
          result.stop =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )!
                  as DateTime;
          break;
        case 'sourceId':
          result.sourceId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'title':
          result.title =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'subtitle':
          result.subtitle = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'description':
          result.description = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'category':
          result.category = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'episodeNum':
          result.episodeNum = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
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

class _$EpgProgramme extends EpgProgramme {
  @override
  final String channelId;
  @override
  final DateTime start;
  @override
  final DateTime stop;
  @override
  final String sourceId;
  @override
  final String title;
  @override
  final String? subtitle;
  @override
  final String? description;
  @override
  final String? category;
  @override
  final String? episodeNum;
  @override
  final String? catchupId;

  factory _$EpgProgramme([void Function(EpgProgrammeBuilder)? updates]) =>
      (EpgProgrammeBuilder()..update(updates))._build();

  _$EpgProgramme._({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.sourceId,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
    this.episodeNum,
    this.catchupId,
  }) : super._();
  @override
  EpgProgramme rebuild(void Function(EpgProgrammeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EpgProgrammeBuilder toBuilder() => EpgProgrammeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EpgProgramme &&
        channelId == other.channelId &&
        start == other.start &&
        stop == other.stop &&
        sourceId == other.sourceId &&
        title == other.title &&
        subtitle == other.subtitle &&
        description == other.description &&
        category == other.category &&
        episodeNum == other.episodeNum &&
        catchupId == other.catchupId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, channelId.hashCode);
    _$hash = $jc(_$hash, start.hashCode);
    _$hash = $jc(_$hash, stop.hashCode);
    _$hash = $jc(_$hash, sourceId.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, subtitle.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, category.hashCode);
    _$hash = $jc(_$hash, episodeNum.hashCode);
    _$hash = $jc(_$hash, catchupId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EpgProgramme')
          ..add('channelId', channelId)
          ..add('start', start)
          ..add('stop', stop)
          ..add('sourceId', sourceId)
          ..add('title', title)
          ..add('subtitle', subtitle)
          ..add('description', description)
          ..add('category', category)
          ..add('episodeNum', episodeNum)
          ..add('catchupId', catchupId))
        .toString();
  }
}

class EpgProgrammeBuilder
    implements Builder<EpgProgramme, EpgProgrammeBuilder> {
  _$EpgProgramme? _$v;

  String? _channelId;
  String? get channelId => _$this._channelId;
  set channelId(String? channelId) => _$this._channelId = channelId;

  DateTime? _start;
  DateTime? get start => _$this._start;
  set start(DateTime? start) => _$this._start = start;

  DateTime? _stop;
  DateTime? get stop => _$this._stop;
  set stop(DateTime? stop) => _$this._stop = stop;

  String? _sourceId;
  String? get sourceId => _$this._sourceId;
  set sourceId(String? sourceId) => _$this._sourceId = sourceId;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _subtitle;
  String? get subtitle => _$this._subtitle;
  set subtitle(String? subtitle) => _$this._subtitle = subtitle;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _category;
  String? get category => _$this._category;
  set category(String? category) => _$this._category = category;

  String? _episodeNum;
  String? get episodeNum => _$this._episodeNum;
  set episodeNum(String? episodeNum) => _$this._episodeNum = episodeNum;

  String? _catchupId;
  String? get catchupId => _$this._catchupId;
  set catchupId(String? catchupId) => _$this._catchupId = catchupId;

  EpgProgrammeBuilder() {
    EpgProgramme._initialize(this);
  }

  EpgProgrammeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _channelId = $v.channelId;
      _start = $v.start;
      _stop = $v.stop;
      _sourceId = $v.sourceId;
      _title = $v.title;
      _subtitle = $v.subtitle;
      _description = $v.description;
      _category = $v.category;
      _episodeNum = $v.episodeNum;
      _catchupId = $v.catchupId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EpgProgramme other) {
    _$v = other as _$EpgProgramme;
  }

  @override
  void update(void Function(EpgProgrammeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EpgProgramme build() => _build();

  _$EpgProgramme _build() {
    final _$result =
        _$v ??
        _$EpgProgramme._(
          channelId: BuiltValueNullFieldError.checkNotNull(
            channelId,
            r'EpgProgramme',
            'channelId',
          ),
          start: BuiltValueNullFieldError.checkNotNull(
            start,
            r'EpgProgramme',
            'start',
          ),
          stop: BuiltValueNullFieldError.checkNotNull(
            stop,
            r'EpgProgramme',
            'stop',
          ),
          sourceId: BuiltValueNullFieldError.checkNotNull(
            sourceId,
            r'EpgProgramme',
            'sourceId',
          ),
          title: BuiltValueNullFieldError.checkNotNull(
            title,
            r'EpgProgramme',
            'title',
          ),
          subtitle: subtitle,
          description: description,
          category: category,
          episodeNum: episodeNum,
          catchupId: catchupId,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
