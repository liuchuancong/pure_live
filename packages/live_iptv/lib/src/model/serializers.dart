import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:live_iptv/src/model/epg_channel/epg_channel.dart';
import 'package:live_iptv/src/model/epg_mapping/epg_mapping.dart';
import 'package:live_iptv/src/model/epg_programme/epg_programme.dart';
import 'package:live_iptv/src/model/epg_source/epg_source.dart';
import 'package:live_iptv/src/model/iptv_channel/iptv_channel.dart';
import 'package:live_iptv/src/model/iptv_entry/iptv_entry.dart';
import 'package:live_iptv/src/model/iptv_group/iptv_group.dart';
import 'package:live_iptv/src/model/iptv_playlist/iptv_playlist.dart';

part 'serializers.g.dart';

/// The model layer's serialization table: every persisted model registers
/// here, and the plugin defines the wire format — `DateTime` as UTC
/// microseconds-since-epoch integers (built_value's `DateTimeSerializer`
/// refuses a local instant and answers `int` back, so older ISO-text rows
/// cannot load through this table). Records live as local dates in memory;
/// `StorageIptvStore` is where the two clocks meet.
@SerializersFor([IptvEntry, IptvChannel, IptvGroup, IptvPlaylist, EpgChannel, EpgMapping, EpgProgramme, EpgSource])
final Serializers serializers = (_$serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
