import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The danmaku shield's whole rule set: the master switch plus the blocked
/// keywords and the blocked users. Everything persists under
/// `danmaku.block.*` — the two lists as string lists, the switch as a
/// bool — and the lists apply in the live room's danmaku pipeline, which
/// arrives with the player stack; the store and the editing stand ready
/// here.
typedef ShieldRules = ({bool enabled, List<String> keywords, List<String> users});

const ShieldRules _defaults = (enabled: true, keywords: <String>[], users: <String>[]);

const String _keywordsKey = 'danmaku.block.keywords';
const String _usersKey = 'danmaku.block.users';
const String _enabledKey = 'danmaku.block.enabled';

/// Owns the danmaku shield's rules: every edit moves the state first and
/// then writes through, so the pane answers at once and a closed store
/// only loses the persistence (the refresh settings' pattern).
base class ShieldRulesController extends Notifier<ShieldRules> {
  @override
  ShieldRules build() {
    try {
      return (
        enabled: StoragePrefs.getBool(_enabledKey) ?? _defaults.enabled,
        keywords: StoragePrefs.getStringList(_keywordsKey) ?? _defaults.keywords,
        users: StoragePrefs.getStringList(_usersKey) ?? _defaults.users,
      );
    } on Object {
      return _defaults;
    }
  }

  /// Flips the master switch, writing the choice through.
  Future<void> setEnabled({required bool value}) async {
    state = (enabled: value, keywords: state.keywords, users: state.users);
    await persist(_enabledKey, value);
  }

  /// Adds [raw] to the blocked keywords (trimmed; an empty or duplicate
  /// paste answers false and changes nothing).
  Future<bool> addKeyword(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || state.keywords.contains(value)) return false;
    state = (enabled: state.enabled, keywords: [...state.keywords, value], users: state.users);
    await persist(_keywordsKey, state.keywords);
    return true;
  }

  /// Removes [value] from the blocked keywords; an absent entry is a no-op.
  Future<void> removeKeyword(String value) async {
    if (!state.keywords.contains(value)) return;
    state = (
      enabled: state.enabled,
      keywords: state.keywords.where((entry) => entry != value).toList(),
      users: state.users,
    );
    await persist(_keywordsKey, state.keywords);
  }

  /// Drops every blocked keyword.
  Future<void> clearKeywords() async {
    if (state.keywords.isEmpty) return;
    state = (enabled: state.enabled, keywords: const [], users: state.users);
    await persist(_keywordsKey, const []);
  }

  /// Replaces the blocked keywords with [values] — the list editor's save:
  /// the draft carries the order the viewer chose and the rows they kept.
  Future<void> setKeywords(List<String> values) async {
    state = (enabled: state.enabled, keywords: List.unmodifiable(values), users: state.users);
    await persist(_keywordsKey, state.keywords);
  }

  /// Adds [raw] to the blocked users (trimmed; an empty or duplicate paste
  /// answers false and changes nothing).
  Future<bool> addUser(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || state.users.contains(value)) return false;
    state = (enabled: state.enabled, keywords: state.keywords, users: [...state.users, value]);
    await persist(_usersKey, state.users);
    return true;
  }

  /// Removes [value] from the blocked users; an absent entry is a no-op.
  Future<void> removeUser(String value) async {
    if (!state.users.contains(value)) return;
    state = (
      enabled: state.enabled,
      keywords: state.keywords,
      users: state.users.where((entry) => entry != value).toList(),
    );
    await persist(_usersKey, state.users);
  }

  /// Drops every blocked user.
  Future<void> clearUsers() async {
    if (state.users.isEmpty) return;
    state = (enabled: state.enabled, keywords: state.keywords, users: const []);
    await persist(_usersKey, const []);
  }

  /// Replaces the blocked users with [values] — the list editor's save.
  Future<void> setUsers(List<String> values) async {
    state = (enabled: state.enabled, keywords: state.keywords, users: List.unmodifiable(values));
    await persist(_usersKey, state.users);
  }

  /// Writes one rule through to the store.
  Future<void> persist(String key, Object? value) async {
    try {
      await StoragePrefs.setAnyPref(key, value);
    } on Object {
      // The rules are a preference; a closed store loses them, nothing else.
    }
  }
}

/// The danmaku shield's rules.
final shieldRulesProvider = NotifierProvider<ShieldRulesController, ShieldRules>(ShieldRulesController.new);
