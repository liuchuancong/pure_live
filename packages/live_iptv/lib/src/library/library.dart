/// The IPTV channel library and the storage seam it sits on.
///
/// One public unit per folder, the folder named after the unit, as in
/// `src/model/`: `IptvLibrary` in `iptv_library/`, the persistence seam
/// `IptvStore` in `iptv_store/`, its keys in `iptv_keys/`, and its two
/// implementations beside them. The library owns the in-memory state and the
/// rules about what a write means; the store knows only documents.
library;

export 'box_iptv_store/box_iptv_store.dart';
export 'in_memory_iptv_store/in_memory_iptv_store.dart';
export 'iptv_keys/iptv_keys.dart';
export 'iptv_library/iptv_library.dart';
export 'iptv_store/iptv_store.dart';
export 'library_iptv_channel_source/library_iptv_channel_source.dart';
