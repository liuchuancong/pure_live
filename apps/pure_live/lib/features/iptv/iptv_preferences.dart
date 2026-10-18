// ignore_for_file: unnecessary_type_name_in_constructor -- the fromJson
// factory cannot use the `new` shorthand.
import 'dart:async';

import 'package:live_storage/live_storage.dart' show StorageRepository;

/// Where the IPTV document is persisted.
///
/// One document per preference group in the shared `settings.preferences`
/// box, versioned in its key — the same discipline the appearance document
/// follows (`lib/app/theme/appearance_preferences`), so a reshaped IPTV
/// document resets the IPTV viewer state and never another group's settings.
/// The playlists themselves are not here: the `IptvLibrary` owns them in its
/// own box, and this document only carries where the viewer left off.
abstract final class IptvKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The IPTV group key.
  static const String document = 'preferences.iptv.v1';
}

/// An Xtream Codes account the user added as a source, as persisted.
///
/// The credentials are everything an Xtream catalogue read needs; [epgUrl]
/// is the per-source programme guide the play page reads when it is set — an
/// empty one means no guide, and no guide strip, rather than a guessed
/// address.
final class IptvXtreamSource {
  /// An Xtream source record.
  const new({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.epgUrl = '',
  });

  /// Restores a record; unknown shapes decode to the blanks.
  factory IptvXtreamSource.fromJson(Map<String, Object?> json) => IptvXtreamSource(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    epgUrl: json['epgUrl'] as String? ?? '',
  );

  /// The record's id, stable across refreshes.
  final String id;

  /// The name the user gave the source.
  final String name;

  /// The server's base address, such as `http://example.tv:8080`.
  final String url;

  /// The account's user name.
  final String username;

  /// The account's password.
  final String password;

  /// The source's XMLTV guide address; empty when the user named none.
  final String epgUrl;

  /// Writes the record.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'epgUrl': epgUrl,
  };

  /// Returns a copy with the given fields replaced.
  IptvXtreamSource copyWith({String? name, String? url, String? username, String? password, String? epgUrl}) =>
      IptvXtreamSource(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        username: username ?? this.username,
        password: password ?? this.password,
        epgUrl: epgUrl ?? this.epgUrl,
      );

  @override
  String toString() => 'IptvXtreamSource($id, $name, $url, user: $username)'; // the password stays out of logs.
}

/// The IPTV viewer's own choices, as persisted: the channel and group a
/// session ended on, so the next one opens where the last one left off, and
/// the Xtream sources — whose credentials live here because the playlists
/// document of the library has no room for a second source shape.
final class IptvPreferences {
  /// The shipping defaults: no channel remembered, every group shown, no
  /// Xtream source.
  const new({this.lastChannelId = '', this.lastGroup = '', this.favoritesOnly = false, this.xtreamSources = const []});

  /// Reads the document; unknown shapes decode to the defaults.
  factory IptvPreferences.fromJson(Map<String, Object?> json) => IptvPreferences(
    lastChannelId: json['lastChannelId'] as String? ?? '',
    lastGroup: json['lastGroup'] as String? ?? '',
    favoritesOnly: json['favoritesOnly'] as bool? ?? false,
    xtreamSources: [
      for (final source in (json['xtreamSources'] as List<Object?>? ?? const <Object?>[]))
        if (source is Map) IptvXtreamSource.fromJson(Map<String, Object?>.from(source)),
    ],
  );

  /// The channel the last session played; empty when none did.
  final String lastChannelId;

  /// The group the channel list was filtered to; empty means every group.
  final String lastGroup;

  /// Whether the channel list was filtered to favourites.
  final bool favoritesOnly;

  /// The Xtream sources, in the order the user added them.
  final List<IptvXtreamSource> xtreamSources;

  /// Writes the document.
  Map<String, Object?> toJson() => {
    'lastChannelId': lastChannelId,
    'lastGroup': lastGroup,
    'favoritesOnly': favoritesOnly,
    'xtreamSources': [for (final source in xtreamSources) source.toJson()],
  };

  /// Returns a copy with the given fields replaced.
  IptvPreferences copyWith({
    String? lastChannelId,
    String? lastGroup,
    bool? favoritesOnly,
    List<IptvXtreamSource>? xtreamSources,
  }) => IptvPreferences(
    lastChannelId: lastChannelId ?? this.lastChannelId,
    lastGroup: lastGroup ?? this.lastGroup,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    xtreamSources: xtreamSources ?? this.xtreamSources,
  );
}

/// What a [IptvPreferencesStore.load] or write found wrong.
///
/// The same shape as the appearance store's failures: a broken document keeps
/// its defaults and the fact is reported, never thrown.
enum IptvPreferencesFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The IPTV viewer's persisted choices: one in-memory [IptvPreferences], one
/// JSON document through a storage repository.
///
/// Reads are synchronous so a page can consult the values as it builds;
/// writes are immediate (a channel switch happens a few times per session,
/// unlike the font-scale slider, so it needs no debounce) — the same shape
/// the desktop shell's store uses.
final class IptvPreferencesStore {
  /// A store persisting through [repository].
  new({required this.repository, this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(IptvPreferencesFailure failure, Object error, StackTrace stack)? onError;
  final StreamController<IptvPreferences> _controller = StreamController<IptvPreferences>.broadcast();

  IptvPreferences _value = const IptvPreferences();
  bool _disposed = false;

  /// The current choices: the shipping defaults until [load] runs.
  IptvPreferences get value => _value;

  /// Emits on every applied change, including [load].
  Stream<IptvPreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes.
  ///
  /// A document that cannot be read or decoded leaves [value] as it is and is
  /// recorded through [onError]; a missing document is not a failure, it is
  /// simply the first run.
  Future<IptvPreferences> load() async {
    _checkNotDisposed();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(IptvKeys.document);
    } on Object catch (error, stack) {
      _report(IptvPreferencesFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final IptvPreferences loaded;
    try {
      loaded = IptvPreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(IptvPreferencesFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return loaded;
  }

  /// Applies [transform] to the choices and persists the result.
  ///
  /// The returned future completes once the change is durable.
  Future<void> update(IptvPreferences Function(IptvPreferences preferences) transform) async {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return;
    }
    _value = fresh;
    _emit();
    try {
      await repository.save(IptvKeys.document, fresh.toJson());
    } on Object catch (error, stack) {
      _report(IptvPreferencesFailure.write, error, stack);
    }
  }

  /// Flushes nothing (writes are immediate) and closes the store; later
  /// [load] and [update] throw, [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _controller.close();
  }

  void _report(IptvPreferencesFailure failure, Object error, StackTrace stack) => onError?.call(failure, error, stack);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('IptvPreferencesStore was disposed');
    }
  }
}
