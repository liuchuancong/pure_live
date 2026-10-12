/// The document keys the IPTV library owns.
///
/// Every key is versioned in its own name (`…​.v1`) because the shape of a
/// document changes while users keep their libraries: a reader that meets
/// the old spelling can still find it, and a writer of the new one does not
/// silently overwrite a record another build is reading.
abstract final class IptvKeys {
  /// The box the IPTV library owns in the shared storage.
  static const String table = 'iptv';

  /// Library channels.
  static const String channels = 'iptv.channels.v1';

  /// Imported playlists.
  static const String playlists = 'iptv.playlists.v1';

  /// Guide sources.
  static const String guideSources = 'iptv.guideSources.v1';

  /// Stored guide channels.
  static const String guideChannels = 'iptv.guideChannels.v1';

  /// Stored programmes.
  static const String guideProgrammes = 'iptv.guideProgrammes.v1';

  /// Channel-to-guide mappings.
  static const String guideMappings = 'iptv.guideMappings.v1';

  /// The group records the user arranged.
  ///
  /// A separate document from the channels on purpose: a group is a fact
  /// about the *list*, and a re-import replaces channel records while it
  /// must not touch this one.
  static const String groups = 'iptv.groups.v1';

  /// The last probe verdict per address.
  ///
  /// Not folded into the channel record: a verdict belongs to an address
  /// that several channels share, and copying it per channel would have to
  /// be re-earned for every one of them.
  static const String lineHealth = 'iptv.lineHealth.v1';
}
