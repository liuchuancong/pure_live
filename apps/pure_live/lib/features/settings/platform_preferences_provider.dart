import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Whether YouTube's live chat asks for every message instead of the web's
/// default Top chat (the reference's `youtubeShowAllChat`).
const String kYoutubeAllChatKey = 'sites.youtube.allChat';

/// Whether Huya's streams prefer H.264 when the platform offers both
/// codecs (the reference's `preferH264`; on by default).
const String kPreferH264Key = 'sites.huya.preferH264';

/// Owns the YouTube chat scope.
final class YoutubeAllChatController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kYoutubeAllChatKey) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kYoutubeAllChatKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Owns Huya's H.264 preference.
final class PreferH264Controller extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kPreferH264Key) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kPreferH264Key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether YouTube shows all live chat.
final youtubeAllChatProvider = NotifierProvider<YoutubeAllChatController, bool>(
  YoutubeAllChatController.new,
);

/// Whether Huya prefers H.264.
final preferH264Provider = NotifierProvider<PreferH264Controller, bool>(PreferH264Controller.new);

/// Whether the Douyu login is renewed every five minutes while the app runs
/// (the reference's `douyuForceRenew`).
const String kDouyuForceRenewKey = 'sites.douyu.forceRenew';

/// Owns the forced renewal switch.
final class DouyuForceRenewController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(kDouyuForceRenewKey) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(kDouyuForceRenewKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The Douyu forced renewal switch.
final douyuForceRenewProvider = NotifierProvider<DouyuForceRenewController, bool>(
  DouyuForceRenewController.new,
);
