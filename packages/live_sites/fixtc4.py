import io
p = 'lib/src/platforms/twitcasting/parsers/twitcasting_parser.dart'
with io.open(p, 'r', encoding='utf-8') as f: t = f.read()
old = "final inner = RegExp('<' + tag + r'\b[^>]*>', caseSensitive: false).firstMatch(rest);"
new = "final inner = RegExp('<$tag" + chr(92) + chr(92) + "b[^>]*>', caseSensitive: false).firstMatch(rest);"
assert old in t, 'anchor missing'
t = t.replace(old, new, 1)
with io.open(p, 'w', encoding='utf-8', newline='\n') as f: f.write(t)
print('ok')
