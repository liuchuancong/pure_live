import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// When douyu's login cookie was saved or last renewed, in epoch seconds
/// (0 = never). Beside the credential itself, this is what turns an opaque
/// web `dy_auth` into a date: the token carries no `exp`, so the seven-day
/// lifetime is counted from here (the package's `DouyuAccount.webCookieLifetime`).
///
/// It travels through the settings store, so it is backed up and restored
/// like every other preference; the secret half of the login (the cookie and
/// the renewal pair) lives in the vault instead.
const String kDouyuCookieSavedAtKey = 'sites.douyu.cookieSavedAt';

/// Owns the douyu cookie's save time.
///
/// The value is the epoch seconds; 0 means unset. It is the reactive mirror
/// of [kDouyuCookieSavedAtKey]: the account page watches it so the status card
/// moves the moment a save or a renewal stamps a new time, and a restore or
/// another window's write rebuilds it through the settings refresh list.
final class DouyuCookieSavedAtController extends Notifier<int> {
  @override
  int build() {
    try {
      return StoragePrefs.getInt(kDouyuCookieSavedAtKey) ?? 0;
    } on Object {
      return 0;
    }
  }

  /// Stamps [moment] (default: now) as the time the login was saved or
  /// renewed.
  Future<void> markSaved([DateTime? moment]) async {
    final seconds = (moment ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    state = seconds;
    try {
      await StoragePrefs.setInt(kDouyuCookieSavedAtKey, seconds);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Clears the save time (the sign-out path: nothing is stored any more).
  Future<void> clear() async {
    state = 0;
    try {
      await StoragePrefs.setInt(kDouyuCookieSavedAtKey, 0);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The douyu login's save time, in epoch seconds.
final douyuCookieSavedAtProvider = NotifierProvider<DouyuCookieSavedAtController, int>(DouyuCookieSavedAtController.new);
