import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/features/backup/webdav/webdav_settings.dart'
    show kWebDavUrlPref, kWebDavUserPref, webdavSecretStoreProvider;

/// One saved WebDAV account.
///
/// The id is the vault name the password hides under
/// (`SecretRefs.webdav(id)`), so a rename never touches the secret; the name
/// is what the page lists, and falls back to the server's host when the
/// viewer typed nothing.
typedef WebDavAccount = ({String id, String name, String url, String user});

/// The saved accounts and which one the file manager shows.
typedef WebDavAccounts = ({List<WebDavAccount> accounts, String selected});

/// The pref key of the account list (a JSON array).
const String kWebDavAccountsPref = 'backup.webdav.accounts';

/// The pref key of the selected account's id.
const String kWebDavSelectedPref = 'backup.webdav.selected';

/// The id the pre-multi-account build's server migrates to. It is also the
/// vault name that build used, so the saved password needs no move.
const String kLegacyWebDavAccountId = 'webdav';

const WebDavAccounts _empty = (accounts: [], selected: '');

/// The address's host, as the account's name when the viewer left it blank.
String webDavAccountNameFromUrl(String url) {
  final host = Uri.tryParse(url.trim())?.host ?? '';
  if (host.isNotEmpty) return host;
  return url.trim().isEmpty ? '' : url.trim();
}

/// Repairs an address the way the reference's does: a bare `host:port` is a
/// WebDAV endpoint typed without its scheme, and the client needs one.
String normalizeWebDavUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  return 'https://$trimmed';
}

/// The stored form of [accounts]: the list as JSON, dropping anything the
/// reader would only have to repair anyway.
String encodeWebDavAccounts(List<WebDavAccount> accounts) => jsonEncode([
  for (final account in accounts)
    {'id': account.id, 'name': account.name, 'url': account.url, 'user': account.user},
]);

/// The accounts a stored JSON array holds; anything malformed stops the read
/// rather than half-loading a list, and the caller falls back to the legacy
/// single-server keys.
List<WebDavAccount>? decodeWebDavAccounts(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return null;
    final accounts = <WebDavAccount>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final id = '${entry['id'] ?? ''}'.trim();
      final url = '${entry['url'] ?? ''}'.trim();
      if (id.isEmpty || url.isEmpty) continue;
      accounts.add((
        id: id,
        name: '${entry['name'] ?? ''}'.trim(),
        url: url,
        user: '${entry['user'] ?? ''}'.trim(),
      ));
    }
    return accounts;
  } on Object {
    return null;
  }
}

/// Owns the saved WebDAV accounts.
///
/// The list is one JSON pref and the selected id another, so a backup carries
/// every server without knowing anything about their shape; the passwords stay
/// in the device vault, one ref per account id.
final class WebDavAccountsController extends Notifier<WebDavAccounts> {
  @override
  WebDavAccounts build() {
    final stored = decodeWebDavAccounts(_read(kWebDavAccountsPref));
    if (stored != null) {
      if (stored.isEmpty) return _empty;
      final selected = _read(kWebDavSelectedPref);
      return (
        accounts: stored,
        selected: stored.any((account) => account.id == selected) ? selected : stored.first.id,
      );
    }
    return _migrate();
  }

  /// The pre-multi-account build's single server, if it is still there.
  ///
  /// Its id is the vault name that build saved the password under, so the
  /// secret needs no move; the two old prefs are then cleared and the list
  /// written, which is what makes this a one-way, once-only step.
  WebDavAccounts _migrate() {
    final url = _read(kWebDavUrlPref).trim();
    if (url.isEmpty) return _empty;
    final migrated = (
      accounts: [
        (
          id: kLegacyWebDavAccountId,
          name: webDavAccountNameFromUrl(url),
          url: url,
          user: _read(kWebDavUserPref).trim(),
        ),
      ],
      selected: kLegacyWebDavAccountId,
    );
    unawaited(_write(migrated));
    return migrated;
  }

  /// The account the file manager shows, or null when none is saved.
  WebDavAccount? get current {
    final accounts = state.accounts;
    for (final account in accounts) {
      if (account.id == state.selected) return account;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  /// Makes [id] the account the file manager shows.
  Future<void> select(String id) async {
    if (!state.accounts.any((account) => account.id == id)) return;
    await _write((accounts: state.accounts, selected: id));
  }

  /// Adds or replaces an account. A null [password] keeps the stored secret,
  /// an empty one clears it, anything else stores it. Answers the id the
  /// account ended up with, which is how a caller finds its own new entry.
  Future<String> save({
    required WebDavAccount account,
    required String? password,
  }) async {
    final id = account.id.isEmpty ? _newAccountId(account.url) : account.id;
    final next = (id: id, name: account.name, url: account.url, user: account.user);
    final others = [for (final other in state.accounts) if (other.id != id) other];
    final accounts = [...others, next];
    await _write((accounts: accounts, selected: state.selected.isEmpty ? id : state.selected));
    if (password != null) {
      await writeAccountPassword(await _secretStore(), id: id, password: password);
    }
    return id;
  }

  /// Removes an account and its stored password.
  Future<void> remove(String id) async {
    final accounts = [for (final account in state.accounts) if (account.id != id) account];
    final selected = state.selected == id ? (accounts.isEmpty ? '' : accounts.first.id) : state.selected;
    await _write((accounts: accounts, selected: selected));
    await writeAccountPassword(await _secretStore(), id: id, password: '');
  }

  Future<void> _write(WebDavAccounts next) async {
    state = next;
    try {
      await StoragePrefs.setString(kWebDavAccountsPref, encodeWebDavAccounts(next.accounts));
      await StoragePrefs.setString(kWebDavSelectedPref, next.selected);
      if (next.accounts.isNotEmpty) {
        // The migration's own keys go with the first write, so the old single
        // server never lingers as a second source of truth.
        await StoragePrefs.remove(kWebDavUrlPref);
        await StoragePrefs.remove(kWebDavUserPref);
      }
    } on Object {
      // The list is a preference; a closed store loses it.
    }
  }

  /// The device vault, or null when it never opened (an unsupported platform,
  /// or a locked keychain). The same shape as `webDavVault`, which is the
  /// widget-side path: a controller holds a `Ref`, not a `WidgetRef`.
  Future<SecretStore?> _secretStore() async {
    try {
      return await ref.read(webdavSecretStoreProvider.future);
    } on Object {
      return null;
    }
  }

  static String _read(String key) {
    try {
      return StoragePrefs.getString(key) ?? '';
    } on Object {
      return '';
    }
  }
}

/// A fresh account id: the address's host plus a counter-free suffix, so two
/// servers on one host still get separate vault refs.
String _newAccountId(String url) {
  final host = webDavAccountNameFromUrl(url).replaceAll(RegExp('[^A-Za-z0-9._-]'), '-');
  final stamp = DateTime.now().millisecondsSinceEpoch.remainder(100000);
  return 'webdav-${host.isEmpty ? 'server' : host}-$stamp';
}

/// Stores an account's password in [store]; an empty [password] clears it.
///
/// A null store means the vault never opened, which is reported by the page's
/// password badge rather than failing the save: the address and the name are
/// already stored and every action still works with an empty password.
Future<void> writeAccountPassword(SecretStore? store, {required String id, required String password}) async {
  if (store == null) return;
  final secretRef = SecretRefs.webdav(id);
  if (password.isEmpty) {
    await store.remove(secretRef);
  } else {
    await store.set(secretRef, password);
  }
}

/// The account's stored password, or '' when the vault holds none (or will not
/// open — an empty password then fails auth loudly, as the reference's does).
Future<String> readAccountPassword(SecretStore? store, String id) async =>
    store?.value(SecretRefs.webdav(id)) ?? '';

/// Whether the vault holds a password for [id].
Future<bool> hasAccountPassword(SecretStore? store, String id) async =>
    (await readAccountPassword(store, id)).isNotEmpty;

/// The saved WebDAV accounts.
final webdavAccountsProvider =
    NotifierProvider<WebDavAccountsController, WebDavAccounts>(WebDavAccountsController.new);
