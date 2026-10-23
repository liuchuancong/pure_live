// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_room.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<LiveRoom> _$liveRoomSerializer = _$LiveRoomSerializer();

class _$LiveRoomSerializer implements StructuredSerializer<LiveRoom> {
  @override
  final Iterable<Type> types = const [LiveRoom, _$LiveRoom];
  @override
  final String wireName = 'LiveRoom';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveRoom object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'ref',
      serializers.serialize(
        object.ref,
        specifiedType: const FullType(LiveRoomRef),
      ),
      'content',
      serializers.serialize(
        object.content,
        specifiedType: const FullType(RoomContent),
      ),
      'audience',
      serializers.serialize(
        object.audience,
        specifiedType: const FullType(RoomAudience),
      ),
      'broadcast',
      serializers.serialize(
        object.broadcast,
        specifiedType: const FullType(RoomBroadcast),
      ),
      'links',
      serializers.serialize(
        object.links,
        specifiedType: const FullType(RoomLinks),
      ),
      'guide',
      serializers.serialize(
        object.guide,
        specifiedType: const FullType(RoomGuide),
      ),
      'local',
      serializers.serialize(
        object.local,
        specifiedType: const FullType(RoomLocal),
      ),
      'runtime',
      serializers.serialize(
        object.runtime,
        specifiedType: const FullType(RoomRuntime),
      ),
    ];
    Object? value;
    value = object.anchor;
    if (value != null) {
      result
        ..add('anchor')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(LiveAnchor),
          ),
        );
    }
    value = object.area;
    if (value != null) {
      result
        ..add('area')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(LiveArea)),
        );
    }
    value = object.createdAt;
    if (value != null) {
      result
        ..add('createdAt')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(DateTime)),
        );
    }
    value = object.updatedAt;
    if (value != null) {
      result
        ..add('updatedAt')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(DateTime)),
        );
    }
    return result;
  }

  @override
  LiveRoom deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LiveRoomBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'ref':
          result.ref.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(LiveRoomRef),
                )!
                as LiveRoomRef,
          );
          break;
        case 'content':
          result.content.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomContent),
                )!
                as RoomContent,
          );
          break;
        case 'audience':
          result.audience.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomAudience),
                )!
                as RoomAudience,
          );
          break;
        case 'broadcast':
          result.broadcast.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomBroadcast),
                )!
                as RoomBroadcast,
          );
          break;
        case 'links':
          result.links.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomLinks),
                )!
                as RoomLinks,
          );
          break;
        case 'guide':
          result.guide.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomGuide),
                )!
                as RoomGuide,
          );
          break;
        case 'local':
          result.local.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomLocal),
                )!
                as RoomLocal,
          );
          break;
        case 'runtime':
          result.runtime.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(RoomRuntime),
                )!
                as RoomRuntime,
          );
          break;
        case 'anchor':
          result.anchor.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(LiveAnchor),
                )!
                as LiveAnchor,
          );
          break;
        case 'area':
          result.area.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(LiveArea),
                )!
                as LiveArea,
          );
          break;
        case 'createdAt':
          result.createdAt = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime?;
          break;
        case 'updatedAt':
          result.updatedAt = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime?;
          break;
      }
    }

    return result.build();
  }
}

class _$LiveRoom extends LiveRoom {
  @override
  final LiveRoomRef ref;
  @override
  final RoomContent content;
  @override
  final RoomAudience audience;
  @override
  final RoomBroadcast broadcast;
  @override
  final RoomLinks links;
  @override
  final RoomGuide guide;
  @override
  final RoomLocal local;
  @override
  final RoomRuntime runtime;
  @override
  final LiveAnchor? anchor;
  @override
  final LiveArea? area;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  factory _$LiveRoom([void Function(LiveRoomBuilder)? updates]) =>
      (LiveRoomBuilder()..update(updates))._build();

  _$LiveRoom._({
    required this.ref,
    required this.content,
    required this.audience,
    required this.broadcast,
    required this.links,
    required this.guide,
    required this.local,
    required this.runtime,
    this.anchor,
    this.area,
    this.createdAt,
    this.updatedAt,
  }) : super._();
  @override
  LiveRoom rebuild(void Function(LiveRoomBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LiveRoomBuilder toBuilder() => LiveRoomBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LiveRoom &&
        ref == other.ref &&
        content == other.content &&
        audience == other.audience &&
        broadcast == other.broadcast &&
        links == other.links &&
        guide == other.guide &&
        local == other.local &&
        runtime == other.runtime &&
        anchor == other.anchor &&
        area == other.area &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, ref.hashCode);
    _$hash = $jc(_$hash, content.hashCode);
    _$hash = $jc(_$hash, audience.hashCode);
    _$hash = $jc(_$hash, broadcast.hashCode);
    _$hash = $jc(_$hash, links.hashCode);
    _$hash = $jc(_$hash, guide.hashCode);
    _$hash = $jc(_$hash, local.hashCode);
    _$hash = $jc(_$hash, runtime.hashCode);
    _$hash = $jc(_$hash, anchor.hashCode);
    _$hash = $jc(_$hash, area.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LiveRoom')
          ..add('ref', ref)
          ..add('content', content)
          ..add('audience', audience)
          ..add('broadcast', broadcast)
          ..add('links', links)
          ..add('guide', guide)
          ..add('local', local)
          ..add('runtime', runtime)
          ..add('anchor', anchor)
          ..add('area', area)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class LiveRoomBuilder implements Builder<LiveRoom, LiveRoomBuilder> {
  _$LiveRoom? _$v;

  LiveRoomRefBuilder? _ref;
  LiveRoomRefBuilder get ref => _$this._ref ??= LiveRoomRefBuilder();
  set ref(LiveRoomRefBuilder? ref) => _$this._ref = ref;

  RoomContentBuilder? _content;
  RoomContentBuilder get content => _$this._content ??= RoomContentBuilder();
  set content(RoomContentBuilder? content) => _$this._content = content;

  RoomAudienceBuilder? _audience;
  RoomAudienceBuilder get audience =>
      _$this._audience ??= RoomAudienceBuilder();
  set audience(RoomAudienceBuilder? audience) => _$this._audience = audience;

  RoomBroadcastBuilder? _broadcast;
  RoomBroadcastBuilder get broadcast =>
      _$this._broadcast ??= RoomBroadcastBuilder();
  set broadcast(RoomBroadcastBuilder? broadcast) =>
      _$this._broadcast = broadcast;

  RoomLinksBuilder? _links;
  RoomLinksBuilder get links => _$this._links ??= RoomLinksBuilder();
  set links(RoomLinksBuilder? links) => _$this._links = links;

  RoomGuideBuilder? _guide;
  RoomGuideBuilder get guide => _$this._guide ??= RoomGuideBuilder();
  set guide(RoomGuideBuilder? guide) => _$this._guide = guide;

  RoomLocalBuilder? _local;
  RoomLocalBuilder get local => _$this._local ??= RoomLocalBuilder();
  set local(RoomLocalBuilder? local) => _$this._local = local;

  RoomRuntimeBuilder? _runtime;
  RoomRuntimeBuilder get runtime => _$this._runtime ??= RoomRuntimeBuilder();
  set runtime(RoomRuntimeBuilder? runtime) => _$this._runtime = runtime;

  LiveAnchorBuilder? _anchor;
  LiveAnchorBuilder get anchor => _$this._anchor ??= LiveAnchorBuilder();
  set anchor(LiveAnchorBuilder? anchor) => _$this._anchor = anchor;

  LiveAreaBuilder? _area;
  LiveAreaBuilder get area => _$this._area ??= LiveAreaBuilder();
  set area(LiveAreaBuilder? area) => _$this._area = area;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  LiveRoomBuilder() {
    LiveRoom._initialize(this);
  }

  LiveRoomBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _ref = $v.ref.toBuilder();
      _content = $v.content.toBuilder();
      _audience = $v.audience.toBuilder();
      _broadcast = $v.broadcast.toBuilder();
      _links = $v.links.toBuilder();
      _guide = $v.guide.toBuilder();
      _local = $v.local.toBuilder();
      _runtime = $v.runtime.toBuilder();
      _anchor = $v.anchor?.toBuilder();
      _area = $v.area?.toBuilder();
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LiveRoom other) {
    _$v = other as _$LiveRoom;
  }

  @override
  void update(void Function(LiveRoomBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LiveRoom build() => _build();

  _$LiveRoom _build() {
    _$LiveRoom _$result;
    try {
      _$result =
          _$v ??
          _$LiveRoom._(
            ref: ref.build(),
            content: content.build(),
            audience: audience.build(),
            broadcast: broadcast.build(),
            links: links.build(),
            guide: guide.build(),
            local: local.build(),
            runtime: runtime.build(),
            anchor: _anchor?.build(),
            area: _area?.build(),
            createdAt: createdAt,
            updatedAt: updatedAt,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'ref';
        ref.build();
        _$failedField = 'content';
        content.build();
        _$failedField = 'audience';
        audience.build();
        _$failedField = 'broadcast';
        broadcast.build();
        _$failedField = 'links';
        links.build();
        _$failedField = 'guide';
        guide.build();
        _$failedField = 'local';
        local.build();
        _$failedField = 'runtime';
        runtime.build();
        _$failedField = 'anchor';
        _anchor?.build();
        _$failedField = 'area';
        _area?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'LiveRoom',
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
