import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:pure_live/core/iptv/models/channel.dart' as model;

import 'playlist_channel_reconciler.dart';

import 'package:drift/drift.dart' as drift;
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:synchronized/synchronized.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:pure_live/core/iptv/parsers/m3u_parser.dart';
import 'package:pure_live/core/iptv/parsers/txt_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class IptvImportManager {
  IptvImportManager({Future<Directory> Function()? cacheDirectory})
    : _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory;
  final Future<Directory> Function() _cacheDirectory;
  static Future<Directory> _defaultCacheDirectory() => AppPathManager().getDir(AppPathManager.dirIptvCache);
  static final _mappingLock = Lock();
  static final _importLock = Lock();

  /// 1. 本地文件浏览器选择导入
  Future<bool> importFromLocalPicker() async {
    final result = await FilePicker.pickFile(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'txt'],
    );

    if (result?.path == null) return false;

    final file = File(result!.path!);
    final name = FileUtils.getBaseName(file.path);
    return await importIptvFile(file: file, providerName: name);
  }

  Future<bool> importFromNetworkUrl(
    String url,
    String fileName, {
    bool forceUpdate = false,
    bool showTips = true,
    bool isHot = false,
  }) async {
    Directory? temporary;
    try {
      final cache = await _cacheDirectory();
      await cache.create(recursive: true);
      temporary = await cache.createTemp('iptv-download-');
      final path = Uri.tryParse(url.trim())?.path.toLowerCase() ?? '';
      var extension = path.endsWith('.txt') ? '.txt' : '.m3u';
      var file = File(p.join(temporary.path, 'input$extension'));
      await HttpClient.instance.download(url, file.path);
      final content = (await _decode(await file.readAsBytes())).trim();
      if (content.startsWith('#EXTM3U')) {
        extension = '.m3u';
      } else if (content.contains(',#genre#') || path.endsWith('.txt')) {
        extension = '.txt';
      } else if (!path.endsWith('.m3u') && !path.endsWith('.m3u8')) {
        if (showTips) ToastUtil.show(i18n('unsupported_file_format'));
        return false;
      }
      if (p.extension(file.path) != extension) file = await file.rename(p.setExtension(file.path, extension));
      return await importIptvFile(
        file: file,
        providerName: _playlistName(fileName),
        url: url,
        forceUpdate: forceUpdate,
        showTips: showTips,
        isHot: isHot,
      );
    } catch (e) {
      debugPrint('Network IPTV Download Failure: $e');
      if (showTips) ToastUtil.show(i18n('download_failed'));
      return false;
    } finally {
      await _cleanupTemporaryDirectory(temporary);
    }
  }

  Future<bool> importFromWebString(
    String fileString,
    String fileName, {
    bool forceUpdate = false,
    bool showTips = true,
  }) async {
    Directory? temporary;
    try {
      final extension = fileString.trim().startsWith('#EXTM3U')
          ? '.m3u'
          : fileName.toLowerCase().endsWith('.txt') || fileString.contains(',#genre#')
          ? '.txt'
          : '.m3u';
      final cache = await _cacheDirectory();
      await cache.create(recursive: true);
      temporary = await cache.createTemp('iptv-web-');
      final file = File(p.join(temporary.path, 'input$extension'));
      await file.writeAsString(fileString);
      return await importIptvFile(
        file: file,
        providerName: _playlistName(fileName),
        forceUpdate: forceUpdate,
        showTips: showTips,
      );
    } catch (e) {
      debugPrint('Web IPTV Import Failure: $e');
      if (showTips) ToastUtil.show(i18n('subscription_download_or_parse_failed'));
      return false;
    } finally {
      await _cleanupTemporaryDirectory(temporary);
    }
  }

  static String _playlistName(String fileName) {
    var name = p.basename(fileName);
    while (p.extension(name).isNotEmpty) {
      name = p.basenameWithoutExtension(name);
    }
    return name;
  }

  static Future<String> _decode(Uint8List bytes) async {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return CharsetConverter.decode('gbk', bytes);
    }
  }

  static Future<void> _cleanupTemporaryDirectory(Directory? directory) async {
    // The directory is the result of this call's createTemp, never a user path.
    if (directory == null) return;
    try {
      await directory.delete(recursive: true);
    } catch (e) {
      debugPrint('IPTV temporary directory cleanup failed: $e');
    }
  }

  Future<bool> importFromSharedMedia(dynamic media, {bool forceUpdate = false, bool showTips = true}) async {
    File? file;
    try {
      if (media.content == null || media.content!.isEmpty) {
        if (showTips) {
          ToastUtil.show(i18n("local_import_failed"));
        }
        return false;
      }

      file = await FileUtils.convertPhysicalFile(media.content!);
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.m3u' && ext != '.m3u8' && ext != '.txt') {
        if (showTips) {
          ToastUtil.show(i18n("unsupported_file_format"));
        }
        return false;
      }

      final success = await importIptvFile(
        file: file,
        providerName: FileUtils.getBaseName(file.path),
        forceUpdate: forceUpdate,
        showTips: showTips,
      );
      return success;
    } catch (e) {
      debugPrint("Shared IPTV Import Process Crash: $e");
      if (showTips) {
        ToastUtil.show(i18n("local_import_failed"));
      }
      return false;
    } finally {
      if (file != null) await FileUtils.cleanupOwnedSharedMediaFile(file);
    }
  }

  Future<bool> deleteProviderDurably(database.Provider expectedProvider) {
    return _importLock.synchronized(() async {
      final db = Get.find<DbService>().db;
      final current = await db.getProviderById(expectedProvider.id);
      if (current != expectedProvider) return false;

      await db.deleteProviderCascading(expectedProvider.id);
      final source = expectedProvider.url;
      if (source != null && source.isNotEmpty) {
        try {
          final cache = await _cacheDirectory();
          await _deleteOwnedLocalFile(source, cache, legacyProviderId: expectedProvider.id, db: db);
        } catch (error) {
          debugPrint('Deleted playlist cache cleanup failed: $error');
        }
      }
      return true;
    });
  }

  Future<bool> importIptvFile({
    required File file,
    required String providerName,
    bool isHot = false,
    String url = '',
    bool forceUpdate = false,
    bool showTips = true,
    database.Provider? expectedProvider,
  }) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      final cleanName = providerName.trim();
      if (cleanName.isEmpty || !{'.m3u', '.m3u8', '.txt'}.contains(ext)) return false;
      final bytes = await file.readAsBytes();
      final content = await _decode(bytes);
      // Parser IDs are transient. Reconciliation selects durable IDs at commit.
      final parsed = ext == '.txt'
          ? TxtParser().parse(content, providerId: '')
          : M3uParser().parse(content, providerId: '');
      // A partial parse is not a complete replacement snapshot. Keep the old
      // playlist if a stanza was truncated or rejected instead of pruning it.
      if (parsed.hasErrors) {
        throw FormatException('Playlist parse failed: ${parsed.errors.first}');
      }
      if (parsed.channels.isEmpty) {
        if (showTips) ToastUtil.show(i18n('unsupported_file_format'));
        return false;
      }
      bool cancelled = false;
      final success = await _importLock.synchronized(() async {
        final db = Get.find<DbService>().db;
        database.Provider? existing;
        final hot = isHot || providerName == 'hot';
        if (expectedProvider != null) {
          existing = await db.getProviderById(expectedProvider.id);
          if (existing != expectedProvider) return false;
        } else if (hot) {
          existing = await db.getProviderById(FileUtils.systemHotProviderId);
        } else {
          final matches = (await db.getAllProviders())
              .where(
                (e) => e.id != FileUtils.systemHotProviderId && e.name.trim().toLowerCase() == cleanName.toLowerCase(),
              )
              .toList();
          if (matches.length > 1) {
            final byUrl = matches.where((e) => url.isNotEmpty && e.url == url).toList();
            if (byUrl.length != 1) {
              throw StateError('Multiple saved playlists share this name; select a source to refresh');
            }
            existing = byUrl.single;
          } else if (matches.isNotEmpty) {
            existing = matches.single;
          }
        }
        if (existing != null && !hot && !forceUpdate) {
          final confirmed = await Get.dialog<bool>(
            Builder(
              builder: (context) => AlertDialog(
                scrollable: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(i18n('provider_name_exists_tip')),
                content: Text(
                  '"$cleanName"\n\n${i18n("replace_confirm_message").replaceAll("{}", ext == '.txt' ? 'TXT' : 'M3U')}',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(i18n('cancel'))),
                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(i18n('confirm'))),
                ],
              ),
            ),
            barrierDismissible: false,
          );
          if (confirmed != true) {
            cancelled = true;
            return false;
          }
        }
        final providerId = existing?.id ?? (hot ? FileUtils.systemHotProviderId : const Uuid().v4());
        await _saveToDatabase(
          bytes: bytes,
          ext: ext,
          providerId: providerId,
          providerName: cleanName,
          url: url,
          channels: parsed.channels,
          expected: existing,
        );
        return true;
      });
      if (showTips && !cancelled) ToastUtil.show(i18n(success ? 'sync_success' : 'sync_failed'));
      return success;
    } catch (e) {
      debugPrint('IPTV Import Error: $e');
      if (showTips) ToastUtil.show('${i18n("sync_failed")}: $e');
      return false;
    }
  }

  Future<void> _saveToDatabase({
    required List<int> bytes,
    required String ext,
    required String providerId,
    required String providerName,
    required String url,
    required List<model.Channel> channels,
    required database.Provider? expected,
  }) async {
    final db = Get.find<DbService>().db;
    Directory? cache;
    File? staged;
    bool committed = false;
    bool ownsStaged = false;
    try {
      // Network sources are re-fetchable. Only local sources need a durable file.
      // Publish a new immutable file; never overwrite the active source's bytes.
      if (url.isEmpty) {
        cache = await _cacheDirectory();
        await cache.create(recursive: true);
        staged = File(p.join(cache.path, 'playlist_${const Uuid().v4()}$ext'));
        await staged.create(exclusive: true);
        ownsStaged = true;
        await staged.writeAsBytes(bytes, flush: true);
      }
      final sourceUrl = url.isEmpty ? staged!.path : url;
      // Lock order is mapping -> database for both callers; never wait for the
      // mapping lock while holding a database transaction owned by this import.
      await _mappingLock.synchronized(
        () => db.transaction(() async {
          final current = await db.getProviderById(providerId);
          if (current != expected) throw StateError('Saved playlist changed while import was pending');
          final previous = await db.getChannelsForProvider(providerId);
          final entries = reconcilePlaylistChannels(providerId: providerId, previous: previous, incoming: channels);
          if (current == null) {
            await db.upsertProvider(
              database.ProvidersCompanion.insert(
                id: providerId,
                name: providerName,
                type: ext.substring(1),
                url: drift.Value(sourceUrl),
                lastRefresh: drift.Value(DateTime.now()),
                isAutoUpdate: drift.Value(url.isNotEmpty && SettingsService.to.iptv.isAutoSyncEnabled.value),
              ),
            );
          } else {
            await (db.update(db.providers)..where((t) => t.id.equals(providerId))).write(
              database.ProvidersCompanion(
                name: drift.Value(providerName),
                type: drift.Value(ext.substring(1)),
                url: drift.Value(sourceUrl),
                lastRefresh: drift.Value(DateTime.now()),
              ),
            );
          }
          await db.upsertChannels(entries);
          final retained = entries.map((e) => e.id.value).toSet();
          await db.batch((batch) {
            for (final old in previous.where((e) => !retained.contains(e.id))) {
              batch.deleteWhere(db.epgMappings, (t) => t.channelId.equals(old.id) & t.providerId.equals(providerId));
              batch.deleteWhere(db.favoriteListChannels, (t) => t.channelId.equals(old.id));
              batch.deleteWhere(db.failoverGroupChannels, (t) => t.channelId.equals(old.id));
              batch.deleteWhere(db.channels, (t) => t.id.equals(old.id) & t.providerId.equals(providerId));
            }
          });
          await _rebuildEpgMappings(providerId: providerId);
        }),
      );
      committed = true;
      // Cleanup is best effort after commit. A cleanup error is not import failure.
      if (expected?.url != null && expected!.url != sourceUrl) {
        try {
          cache ??= await _cacheDirectory();
          await _deleteOwnedLocalFile(expected.url!, cache, legacyProviderId: expected.id, db: db);
        } catch (e) {
          debugPrint('Old playlist cache cleanup failed: $e');
        }
      }
    } finally {
      if (!committed && ownsStaged && staged != null) {
        try {
          await staged.delete();
        } catch (e) {
          debugPrint('Uncommitted playlist cleanup failed: $e');
        }
      }
    }
  }

  static String? _localPlaylistPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'file') return File.fromUri(uri!).path;
    if (uri != null && uri.hasScheme && !p.isAbsolute(value)) return null;
    return value;
  }

  static Future<void> _deleteOwnedLocalFile(
    String path,
    Directory cache, {
    required String legacyProviderId,
    required database.AppDatabase db,
  }) async {
    final candidate = _localPlaylistPath(path);
    if (candidate == null || !p.equals(p.dirname(p.absolute(candidate)), p.absolute(cache.path))) return;
    final name = p.basename(candidate);
    final versioned = RegExp(r'^playlist_[0-9a-f-]{36}\.(m3u8?|txt)$', caseSensitive: false).hasMatch(name);
    final legacy =
        RegExp(r'^[0-9a-f-]+$', caseSensitive: false).hasMatch(legacyProviderId) &&
        {'.m3u', '.m3u8', '.txt'}.any((ext) => name == '$legacyProviderId$ext');
    if (!versioned && !legacy) return;
    if (await FileSystemEntity.type(candidate, followLinks: false) != FileSystemEntityType.file) return;
    // Keep the DB reference snapshot stable through deletion. URI, separator,
    // case and symlink aliases must not make a shared file look unreferenced.
    await db.transaction(() async {
      final resolved = await File(candidate).resolveSymbolicLinks();
      for (final provider in await db.getAllProviders()) {
        final reference = provider.url == null ? null : _localPlaylistPath(provider.url!);
        if (reference == null) continue;
        if (p.equals(p.absolute(reference), p.absolute(candidate))) return;
        final type = await FileSystemEntity.type(reference, followLinks: false);
        if (type != FileSystemEntityType.file && type != FileSystemEntityType.link) continue;
        if (p.equals(await File(reference).resolveSymbolicLinks(), resolved)) return;
      }
      await File(candidate).delete();
    });
  }

  Future<void> runAutoEpgMapping({required String providerId}) =>
      _mappingLock.synchronized(() => _rebuildEpgMappings(providerId: providerId));

  Future<void> _rebuildEpgMappings({required String providerId}) async {
    final db = Get.find<DbService>().db;
    final selected = SettingsService.to.iptv.selectedSourceId;
    final sourceId = selected.value;
    if (sourceId.isEmpty) return;
    bool sourceChanged = false;
    // A synchronous listener also catches A -> B -> A during a database await.
    final detach = selected.addListener(() => sourceChanged = true);
    void checkSource() {
      if (sourceChanged || selected.isDisposed || selected.value != sourceId) {
        throw const _MappingSourceChanged();
      }
    }

    try {
      await db.transaction(() async {
        if (await db.getProviderById(providerId) == null) return;
        final channels = await db.getChannelsForProvider(providerId);
        final epgChannels = await db.getEpgChannelsForSource(sourceId);
        checkSource();
        // Missing data is not an instruction to remove saved user mappings.
        if (channels.isEmpty || epgChannels.isEmpty) return;
        final previous = await (db.select(db.epgMappings)..where((t) => t.providerId.equals(providerId))).get();
        final byChannel = {for (final mapping in previous) mapping.channelId: mapping};
        final index = _ImportEpgIndex(epgChannels);
        final matched = <String>{};
        final updates = <database.EpgMappingsCompanion>[];
        for (final channel in channels) {
          final old = byChannel[channel.id];
          if (old != null && (old.locked || old.source != 'auto')) continue;
          final epgId = index.match(channel);
          if (epgId == null) continue;
          matched.add(channel.id);
          // Do not reset confidence or timestamps for an unchanged mapping.
          if (old?.epgChannelId == epgId && old?.epgSourceId == sourceId) continue;
          updates.add(
            database.EpgMappingsCompanion.insert(
              channelId: channel.id,
              providerId: providerId,
              epgChannelId: epgId,
              epgSourceId: sourceId,
              source: const drift.Value('auto'),
            ),
          );
        }
        checkSource();
        for (final old in previous) {
          if (!old.locked && old.source == 'auto' && !matched.contains(old.channelId)) {
            await db.deleteMapping(old.channelId, providerId);
          }
        }
        if (updates.isNotEmpty) await db.upsertMappings(updates);
        // Includes changes while SQLite was writing the candidate snapshot.
        checkSource();
      }, requireNew: true);
    } on _MappingSourceChanged {
      // Transaction rollback retains the last committed mapping snapshot.
    } finally {
      detach();
    }
  }
}

class _MappingSourceChanged implements Exception {
  const _MappingSourceChanged();
}

/// Build exact indices once; ambiguous evidence never depends on row order.
class _ImportEpgIndex {
  _ImportEpgIndex(List<database.EpgChannel> channels) {
    for (final channel in channels) {
      final id = channel.channelId.trim().toLowerCase();
      if (id.isNotEmpty) (_byId[id] ??= []).add(channel.id);
      final name = _name(channel.displayName);
      if (name.isNotEmpty) (_byName[name] ??= []).add(channel.id);
    }
  }

  static final _clean = RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]');
  static String _name(String value) => value.toLowerCase().replaceAll(_clean, '');
  final _byId = <String, List<String>>{};
  final _byName = <String, List<String>>{};
  final _nameMatches = <String, String?>{};
  String? _unique(List<String> matches) => matches.length == 1 ? matches.single : null;

  String? match(database.Channel channel) {
    final tvgId = channel.tvgId?.trim().toLowerCase();
    final byTvg = tvgId == null ? null : _byId[tvgId];
    if (byTvg != null) return _unique(byTvg);
    final byLegacyId = _byId[channel.id.trim().toLowerCase()];
    if (byLegacyId != null) return _unique(byLegacyId);
    final name = _name(channel.name);
    if (name.isEmpty) return null;
    if (_nameMatches.containsKey(name)) return _nameMatches[name];
    final exact = _byName[name];
    if (exact != null) return _nameMatches[name] = _unique(exact);
    String? match;
    for (final entry in _byName.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        if (match != null || entry.value.length != 1) return _nameMatches[name] = null;
        match = entry.value.single;
      }
    }
    return _nameMatches[name] = match;
  }
}
