import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/account/account_roster.dart';
import 'package:pure_live/features/account/login_providers.dart';
import 'package:pure_live/features/backup/web_dav_preferences.dart';
import 'package:pure_live/features/backup/web_dav_store.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';

/// The LAN sync service, created on first entry to the sync page and kept
/// for the rest of the process (the 3.x binding was a lazy singleton the
/// same way): the server and discovery keep running after the page closes,
/// so another device's request still reaches the confirm gate.
///
/// The sensitive-section thunks bridge the sync payload to the other
/// features' own stores — the WebDAV store (servers plus their vault
/// passwords) and the login side (each site's active credential document
/// plus its remembered roster entries). They run only while the page's
/// "同步账号 Cookie" switch is on; a store that cannot open contributes
/// nothing rather than failing the whole send.
final remoteSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  final service = RemoteSyncService(
    follows: ref.watch(followRepositoryProvider),
    history: ref.watch(historyRepositoryProvider),
    preferences: ref.watch(appPreferencesStoreProvider),
    webdavExport: () async {
      try {
        final store = await ref.read(webDavStoreProvider.future);
        return [
          for (final server in store.value.servers)
            {
              'name': server.name,
              'address': server.address,
              'username': server.username,
              'directory': server.directory,
              'password': store.passwordOf(server.name),
            },
        ];
      } on Object {
        return const <Map<String, dynamic>>[];
      }
    },
    webdavApply: (entry) async {
      final name = entry['name']?.toString() ?? '';
      if (name.isEmpty) {
        return;
      }
      final store = await ref.read(webDavStoreProvider.future);
      await store.saveServer(
        WebDavServer(
          name: name,
          address: entry['address']?.toString() ?? '',
          username: entry['username']?.toString() ?? '',
          directory: entry['directory']?.toString() ?? '',
        ),
        password: entry['password']?.toString(),
      );
    },
    accountsExport: () async {
      final out = <Map<String, dynamic>>[];
      final sites = ref.read(sitesProvider).registry.all;
      for (final site in sites) {
        final siteId = site.manifest.id;
        final repository = ref.read(loginRepositoryProvider(siteId));
        try {
          final active = await repository.exportDocument();
          if (active != null) {
            out.add({'site': siteId, 'document': active});
          }
        } on Object {
          // A vault that will not open simply has no credential to send.
        }
        try {
          final roster = await ref.read(accountRosterProvider.future);
          for (final account in roster.of(siteId)) {
            out.add({'site': siteId, 'roster': true, 'document': repository.encodeDocument(account.credential)});
          }
        } on Object {
          // Same for the roster.
        }
      }
      return out;
    },
    accountsApply: (entry) async {
      final siteId = entry['site']?.toString() ?? '';
      final document = entry['document']?.toString() ?? '';
      if (siteId.isEmpty || document.isEmpty) {
        return;
      }
      final repository = ref.read(loginRepositoryProvider(siteId));
      final roster = await _roster(ref);
      if (entry['roster'] == true) {
        // A remembered sign-in: it joins the roster, it does not sign the
        // device in as that account.
        final credential = repository.decodeDocument(document);
        if (credential != null) {
          await roster?.remember(credential);
        }
        return;
      }
      final credential = await repository.saveDocument(document);
      // The active sign-in is worth remembering too (3.x restores both).
      if (credential != null) {
        await roster?.remember(credential);
      }
    },
  );
  ref.onDispose(service.dispose);
  unawaited(service.start());
  return service;
});

/// The roster, when the secret vault opens it; null swallows the roster
/// side of an import rather than failing the credential with it.
Future<AccountRoster?> _roster(Ref ref) async {
  try {
    return await ref.read(accountRosterProvider.future);
  } on Object {
    return null;
  }
}
