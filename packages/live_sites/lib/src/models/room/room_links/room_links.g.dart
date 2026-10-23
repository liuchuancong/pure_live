// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_links.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RoomLinks> _$roomLinksSerializer = _$RoomLinksSerializer();

class _$RoomLinksSerializer implements StructuredSerializer<RoomLinks> {
  @override
  final Iterable<Type> types = const [RoomLinks, _$RoomLinks];
  @override
  final String wireName = 'RoomLinks';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RoomLinks object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[];
    Object? value;
    value = object.webUrl;
    if (value != null) {
      result
        ..add('webUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.appUrl;
    if (value != null) {
      result
        ..add('appUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    value = object.shareUrl;
    if (value != null) {
      result
        ..add('shareUrl')
        ..add(serializers.serialize(value, specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  RoomLinks deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RoomLinksBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'webUrl':
          result.webUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'appUrl':
          result.appUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
        case 'shareUrl':
          result.shareUrl = serializers.deserialize(value, specifiedType: const FullType(String)) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$RoomLinks extends RoomLinks {
  @override
  final String? webUrl;
  @override
  final String? appUrl;
  @override
  final String? shareUrl;

  factory _$RoomLinks([void Function(RoomLinksBuilder)? updates]) => (RoomLinksBuilder()..update(updates))._build();

  _$RoomLinks._({this.webUrl, this.appUrl, this.shareUrl}) : super._();
  @override
  RoomLinks rebuild(void Function(RoomLinksBuilder) updates) => (toBuilder()..update(updates)).build();

  @override
  RoomLinksBuilder toBuilder() => RoomLinksBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RoomLinks && webUrl == other.webUrl && appUrl == other.appUrl && shareUrl == other.shareUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, webUrl.hashCode);
    _$hash = $jc(_$hash, appUrl.hashCode);
    _$hash = $jc(_$hash, shareUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RoomLinks')
          ..add('webUrl', webUrl)
          ..add('appUrl', appUrl)
          ..add('shareUrl', shareUrl))
        .toString();
  }
}

class RoomLinksBuilder implements Builder<RoomLinks, RoomLinksBuilder> {
  _$RoomLinks? _$v;

  String? _webUrl;
  String? get webUrl => _$this._webUrl;
  set webUrl(String? webUrl) => _$this._webUrl = webUrl;

  String? _appUrl;
  String? get appUrl => _$this._appUrl;
  set appUrl(String? appUrl) => _$this._appUrl = appUrl;

  String? _shareUrl;
  String? get shareUrl => _$this._shareUrl;
  set shareUrl(String? shareUrl) => _$this._shareUrl = shareUrl;

  RoomLinksBuilder();

  RoomLinksBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _webUrl = $v.webUrl;
      _appUrl = $v.appUrl;
      _shareUrl = $v.shareUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RoomLinks other) {
    _$v = other as _$RoomLinks;
  }

  @override
  void update(void Function(RoomLinksBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RoomLinks build() => _build();

  _$RoomLinks _build() {
    final _$result = _$v ?? _$RoomLinks._(webUrl: webUrl, appUrl: appUrl, shareUrl: shareUrl);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
