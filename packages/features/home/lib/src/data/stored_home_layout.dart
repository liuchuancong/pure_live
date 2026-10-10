// Module: lib/src/data/stored_home_layout.dart
// Purpose: The kv-backed home layout: versioned row, per-app namespace, and a reported rather than silent
// read failure.
// Author: liuchuancong
// Created: 2026-10-10
//
// The row is the user's arrangement of the app's front screen. Two properties follow from that: it has to
// say which app it belongs to (pure_live's tabs are not pure_music's, and they share a database), and it has
// to carry its format version, because adding a field - as this one did, with the hidden set arriving after
// the order - is otherwise indistinguishable from a corrupt row.
//
// The reason this file carried its own envelope at all was a layering fact: the preference mechanism used to
// live in features/settings, a sibling in the same layer, which section 3 forbids importing. The mechanism is
// in pure_live_storage (L0, reachable from here) as of 2026-10-10, so this shape is now the odd one out -
// migrating it onto PreferencesStore is the recorded next step in the ledger, and it needs a
// PreferenceKey.upgrade for rows already stored in the form below.

import 'dart:convert';

import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/home_layout_repository.dart';
import '../domain/home_tab.dart';

/// The envelope version this writer produces.
const int kHomeLayoutEnvelopeVersion = 1;

/// A layout this build could not use, reported instead of swallowed.
final class HomeLayoutReadFailure extends DomainFailure {
  const HomeLayoutReadFailure(super.reason, {super.cause});
}

/// A [HomeLayoutRepository] over one namespaced [KeyValueStore].
final class StoredHomeLayout implements HomeLayoutRepository {
  StoredHomeLayout({required KeyValueStore store, required String namespace, this.onReadFailure})
    : _store = store,
      namespace = requireNonBlank(namespace, name: 'namespace').toLowerCase();

  static const String _suffix = '.home_layout';

  final KeyValueStore _store;
  final void Function(HomeLayoutReadFailure failure)? onReadFailure;

  /// Which app's home this layout belongs to, e.g. `pure_live`. Folded to lower case because it keys a
  /// file-backed store whose names are case-insensitive on Windows.
  final String namespace;

  String get _key => '$namespace$_suffix';

  HomeLayout? _cache;

  @override
  Future<HomeLayout> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final raw = await _store.read(_key);
    final layout = raw == null ? const HomeLayout() : (_decode(raw) ?? const HomeLayout());
    _cache = layout;
    return layout;
  }

  @override
  Future<HomeLayout> save(HomeLayout layout) async {
    _cache = layout;
    await _store.write(
      _key,
      jsonEncode(<String, Object?>{
        'v': kHomeLayoutEnvelopeVersion,
        'order': List<String>.unmodifiable(layout.order),
        'hidden': List<String>.unmodifiable(layout.hidden),
      }),
    );
    return layout;
  }

  @override
  Future<void> reset() async {
    _cache = const HomeLayout();
    await _store.remove(_key);
  }

  HomeLayout? _decode(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      _report('stored value is not text', cause: raw.runtimeType);
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      _report('stored row is not json', cause: error);
      return null;
    }
    final envelope = jsonMapFrom(decoded);
    if (envelope == null) {
      _report('stored row is not an object');
      return null;
    }
    final version = intFrom(envelope['v']) ?? 0;
    if (version > kHomeLayoutEnvelopeVersion) {
      // Written by a newer build; reading it as this version would rewrite fields we do not understand.
      _report('stored envelope version $version is newer than $kHomeLayoutEnvelopeVersion');
      return null;
    }
    // A row without the hidden list predates that field. An absent list means the user never hid a tab,
    // which is the empty list rather than a failure - the difference matters because reporting it as corrupt
    // would reset the order too.
    final order = stringListFrom(envelope['order']);
    if (order == null) {
      _report('envelope has no order list');
      return null;
    }
    final hidden = stringListFrom(envelope['hidden']) ?? const <String>[];
    return HomeLayout(order: List<String>.unmodifiable(order), hidden: List<String>.unmodifiable(hidden));
  }

  void _report(String reason, {Object? cause}) {
    onReadFailure?.call(HomeLayoutReadFailure('home layout for "$namespace" was unusable: $reason', cause: cause));
  }
}
