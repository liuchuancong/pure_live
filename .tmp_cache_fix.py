# -*- coding: utf-8 -*-
import io

p = 'packages/foundation/cache/lib/src/disk_tier.dart'
s = io.open(p, encoding='utf-8').read()

# import the memory tier
old = "import 'policy.dart';"
new = "import 'policy.dart';\nimport 'store.dart';"
assert old in s, 'import'
s = s.replace(old, new)

# write header: setInt64 takes (offset, value, endian)
old = """    final file = _fileFor(key);
    final header = ByteData(8)..getInt64(0, 0, Endian.little);
    final expiresAt = _clock().toUtc().add(ttl).millisecondsSinceEpoch;
    header.setInt64(0, expiresAt, Endian.little);"""
new = """    final file = _fileFor(key);
    final header = ByteData(8);
    final expiresAt = _clock().toUtc().add(ttl).millisecondsSinceEpoch;
    header.setInt64(0, expiresAt, Endian.little);"""
assert old in s, 'write header'
s = s.replace(old, new)

# drop the pointless path sort
old = """    files.sort((a, b) => a.path.compareTo(b.path));
    final byAge = <(File, DateTime)>[];"""
new = """    final byAge = <(File, DateTime)>[];"""
assert old in s, 'sort'
s = s.replace(old, new)

# delete method on the tier
old = """  Future<void> clear() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }
}"""
new = """  Future<void> clear() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }

  Future<void> delete(String key) => _deleteQuietly(_fileFor(key));
}"""
assert old in s, 'delete'
s = s.replace(old, new)

# two-level remove uses it
old = """  Future<void> remove(String key) async {
    memory.remove(key);
    await disk.write(key, const <int>[]); // tombstone: expired on read
  }"""
new = """  Future<void> remove(String key) async {
    memory.remove(key);
    await disk.delete(key);
  }"""
assert old in s, 'remove'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('disk_tier ok')

# pubspec crypto
p = 'packages/foundation/cache/pubspec.yaml'
s = io.open(p, encoding='utf-8').read()
if 'crypto:' not in s:
    old = 'dependencies:'
    assert old in s
    s = s.replace(old, 'dependencies:\n  crypto: ^3.0.7', 1)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('pubspec ok')

# barrel
p = 'packages/foundation/cache/lib/pure_live_cache.dart'
s = io.open(p, encoding='utf-8').read()
if "export 'src/disk_tier.dart';" not in s:
    old = "export 'src/store.dart';"
    assert old in s
    s = s.replace(old, "export 'src/disk_tier.dart';\nexport 'src/store.dart';")
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('barrel ok')
