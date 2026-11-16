import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The music module's preference plumbing, shared by the settings groups:
/// a closed store reads as "not stored" on the way in and loses the write on
/// the way out, instead of throwing through a controller.
String? readMusicPref(String key) {
  try {
    return StoragePrefs.getString(key);
  } on Object {
    return null;
  }
}

/// See [readMusicPref].
bool? readMusicPrefBool(String key) {
  try {
    return StoragePrefs.getBool(key);
  } on Object {
    return null;
  }
}

/// See [readMusicPref].
int? readMusicPrefInt(String key) {
  try {
    return StoragePrefs.getInt(key);
  } on Object {
    return null;
  }
}

/// See [readMusicPref].
double? readMusicPrefDouble(String key) {
  try {
    return StoragePrefs.getDouble(key);
  } on Object {
    return null;
  }
}

/// Writes a string pref; a closed store loses it.
Future<void> writeMusicPref(String key, String value) async {
  try {
    await StoragePrefs.setString(key, value);
  } on Object {
    // A preference; a closed store loses it.
  }
}

/// See [writeMusicPref].
Future<void> writeMusicPrefBool(String key, {required bool value}) async {
  try {
    await StoragePrefs.setBool(key, value);
  } on Object {
    // Same as above.
  }
}

/// See [writeMusicPref].
Future<void> writeMusicPrefInt(String key, int value) async {
  try {
    await StoragePrefs.setInt(key, value);
  } on Object {
    // Same as above.
  }
}

/// See [writeMusicPref].
Future<void> writeMusicPrefDouble(String key, double value) async {
  try {
    await StoragePrefs.setDouble(key, value);
  } on Object {
    // Same as above.
  }
}
