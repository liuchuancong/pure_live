/// 解析 `a=1; b=2` 形式的 Cookie 串为 (name, value) 对；
/// 跳过空段与缺少 `=` 的段，按首个 `=` 切分（值本身可含 `=`）。
List<MapEntry<String, String>> parseCookiePairs(String cookie) {
  final pairs = <MapEntry<String, String>>[];
  for (final part in cookie.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    final name = trimmed.substring(0, idx).trim();
    if (name.isEmpty) continue;
    pairs.add(MapEntry(name, trimmed.substring(idx + 1)));
  }
  return pairs;
}

/// Cookie 域名是否归属 [targets] 中任一域名（后缀匹配，含带点前缀写法）。
bool cookieDomainMatches(String domain, List<String> targets) {
  if (domain.isEmpty) return false;
  return targets.any((d) => domain == d || domain == '.$d' || domain.endsWith('.$d'));
}
