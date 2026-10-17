/// The data records of the IPTV and guide domains.
///
/// One public unit per folder, the folder named after the unit: the record
/// `X` is `model/x/x.dart`, and its generated `x.freezed.dart` and `x.g.dart`
/// sit beside it. A file holding several unrelated records is how a model
/// file stops being reviewable — every change to one of them shows up as a
/// change to all, and the imports of a module say nothing about which record
/// it actually uses.
///
/// Small companions stay with the record they describe rather than becoming
/// files of their own: an extension on its class (`EpgSourceX`,
/// `EpgChannelKeyX`), the key builder of one record (`epgChannelKey` beside
/// `EpgChannel`), the origin constant of one record (`epgAutoMappingOrigin`
/// beside `EpgMapping`), and the format helper of one enum (`streamTypeOf`
/// beside `IptvStreamType`).
library;

export 'epg_channel/epg_channel.dart';
export 'epg_mapping/epg_mapping.dart';
export 'epg_programme/epg_programme.dart';
export 'epg_source/epg_source.dart';
export 'guide_channel/guide_channel.dart';
export 'iptv_channel/iptv_channel.dart';
export 'iptv_entry/iptv_entry.dart';
export 'iptv_group/iptv_group.dart';
export 'iptv_line_health/iptv_line_health.dart';
export 'iptv_playlist/iptv_playlist.dart';
export 'iptv_programme_slot/iptv_programme_slot.dart';
export 'iptv_stream_type/iptv_stream_type.dart';
export 'parsed_guide/parsed_guide.dart';
export 'xtream_source/xtream_source.dart';
