// Module: lib/src/data/stored_home_layout.dart
// Purpose: The home layout as one typed preference: the shared envelope, namespace and reporting from L0.
// Author: liuchuancong
// Created: 2026-10-10
//
// The row is the user's arrangement of the app's front screen, so two properties are fixed: it has to say
// which app it belongs to (pure_live's tabs are not pure_music's, and they share a database), and it has to
// carry its format version, because adding a field - as this one did, with the hidden set arriving after the
// order - is otherwise indistinguishable from a corrupt row.
//
// Both are the preference mechanism's job, so they are no longer implemented here. This file used to hand-roll
// its own `{v, order, hidden}` envelope for a layering reason that has since gone away: the mechanism lived in
// features/settings, a sibling section 3 forbids importing, and it now lives in this package's own dependency,
// pure_live_storage. `upgrade` is what keeps the rows written in that older shape readable - without it the
// first read after this change would answer "empty layout" and the next save would persist that as a choice.

import 'dart:convert';

import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/home_layout_repository.dart';
import '../domain/home_tab.dart';

/// The document version this writer produces, carried inside the stored value.
///
/// It is separate from the mechanism's own envelope version on purpose: the envelope says "a typed preference
/// row", this says "which fields the layout itself has". A row from a newer build is refused rather than
/// half-read, because rewriting fields we do not understand would drop whatever the newer version added.
const int kHomeLayoutEnvelopeVersion = 1;

/// The key this layout is stored under, inside the per-app namespace.
///
/// The name is the one the hand-rolled row used, so `PreferencesStore` reads exactly the rows that are already
/// on disk instead of starting a second key that nothing old feeds.
const String kHomeLayoutPreferenceName = 'home_layout';

/// A layout this build could not use, reported instead of swallowed.
final class HomeLayoutReadFailure extends DomainFailure {
  const HomeLayoutReadFailure(super.reason, {super.cause});
}

/// A [HomeLayoutRepository] over one namespaced preference key.
final class StoredHomeLayout implements HomeLayoutRepository {
  StoredHomeLayout({required KeyValueStore store, required String namespace, this.onReadFailure})
    : namespace = requireNonBlank(namespace, name: 'namespace').toLowerCase() {
    _preferences = PreferencesStore(store: store, namespace: '${this.namespace}.');
  }

  static final PreferenceCodec<HomeLayout> _codec = PreferenceCodec.of<HomeLayout>(
    'homeLayout',
    _decodeDocument,
    (HomeLayout value) => <String, Object?>{
      'v': kHomeLayoutEnvelopeVersion,
      'order': List<String>.unmodifiable(value.order),
      'hidden': List<String>.unmodifiable(value.hidden),
    },
  );

  static final PreferenceKey<HomeLayout> _key = PreferenceKey<HomeLayout>(
    name: kHomeLayoutPreferenceName,
    codec: _codec,
    defaultValue: const HomeLayout(),
    upgrade: _readLegacyRow,
  );

  late final PreferencesStore _preferences;

  /// Which app's home this layout belongs to, e.g. `pure_live`. Folded to lower case because it keys a
  /// file-backed store whose names are case-insensitive on Windows.
  final String namespace;

  /// Called for a row that exists but could not be used. A read still answers the default rather than
  /// throwing: the cost of an unreadable row is the user's arrangement, and the recovery path is the defaults
  /// plus this report, not an exception on the way to the app's first screen.
  final void Function(HomeLayoutReadFailure failure)? onReadFailure;

  HomeLayout? _cache;

  @override
  Future<HomeLayout> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final rejectionsBefore = _preferences.rejections.length;
    final stored = await _preferences.readIfStored(_key);
    if (stored != null) {
      _cache = stored;
      return stored;
    }
    // Only a row this build refused is worth reporting: an untouched key is the normal first-run state, and
    // calling that damage would make every new install look broken.
    if (_preferences.rejections.length > rejectionsBefore) {
      final rejection = _preferences.rejections.last;
      _report(
        'stored row was unusable (${rejection.failure.name}'
        '${rejection.rawType == null ? '' : ', found ${rejection.rawType}'})',
      );
    }
    _cache = const HomeLayout();
    return _cache!;
  }

  @override
  Future<HomeLayout> save(HomeLayout layout) async {
    _cache = layout;
    await _preferences.write(_key, layout);
    return layout;
  }

  @override
  Future<void> reset() async {
    _cache = const HomeLayout();
    await _preferences.reset(_key);
  }

  /// Closes the change stream the shared store publishes. The layout row itself is durable; the store is not
  /// this repository's to keep open once the screen that reads it is gone.
  Future<void> dispose() => _preferences.dispose();

  /// The pre-mechanism row: this file used to write the document as a JSON string under the same key.
  ///
  /// Decoding it here hands the map to the codec, so version and field rules are checked once rather than
  /// being duplicated in two readers.
  static Object? _readLegacyRow(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static HomeLayout? _decodeDocument(Object? raw) {
    final document = jsonMapFrom(raw);
    if (document == null) {
      return null;
    }
    final version = intFrom(document['v']) ?? 0;
    if (version > kHomeLayoutEnvelopeVersion) {
      return null;
    }
    final order = stringListFrom(document['order']);
    if (order == null) {
      return null;
    }
    // A row without the hidden list predates that field. An absent list means the user never hid a tab, which
    // is the empty list rather than a failure - the difference matters because reporting it as corrupt would
    // reset the order too.
    final hidden = stringListFrom(document['hidden']) ?? const <String>[];
    return HomeLayout(order: List<String>.unmodifiable(order), hidden: List<String>.unmodifiable(hidden));
  }

  void _report(String reason, {Object? cause}) {
    onReadFailure?.call(HomeLayoutReadFailure('home layout for "$namespace" was unusable: $reason', cause: cause));
  }
}
