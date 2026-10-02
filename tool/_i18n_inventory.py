"""Inventory hardcoded CJK / English UI strings in lib/ (scratch tool)."""
import pathlib
import re
import sys

LIB = pathlib.Path('lib')


def mask_comments(src):
    """Blank out // and /// comments and /* */ blocks, keeping string bodies."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(' ' * (j - i))
            i = j
        elif c in '"\'':
            quote = c
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == quote:
                    j += 1
                    break
                j += 1
            out.append(src[i:j])
            i = j
        else:
            out.append(c)
            i += 1
    return ''.join(out)


LITERAL = re.compile(r"""(?P<q>['"]){2,3}(?P<t>.*?)(?P=q){1,3}""", re.S)
CJK = re.compile(r'[一-鿿]')

UI_CTX = re.compile(r'(Text\(|\.show\(|ToastUtil|SnackBar|title:|subtitle:|label:|hintText:|helperText:|'
                    r'message:|TextButton|Tooltip\(|AlertDialog|labelText:|semanticLabel:|banner|MenuItem)')
LOG_CTX = re.compile(r'(debugPrint|log\(|developer\.log|print\(|assert|throw)')

rows = []
for path in sorted(LIB.rglob('*.dart')):
    rel = path.as_posix()
    if rel.startswith('lib/get') or rel.endswith('.g.dart') or rel.endswith('.freezed.dart'):
        continue
    if '/proto/' in rel:
        continue
    raw = path.read_text(encoding='utf-8', errors='replace')
    masked = mask_comments(raw)
    lines = raw.split('\n')
    mlines = masked.split('\n')
    for idx, line in enumerate(mlines):
        for m in re.finditer(r"""(['"])((?:\\.|(?!\1).)*)\1""", line):
            text = m.group(2)
            if not text.strip():
                continue
            has_cjk = bool(CJK.search(text))
            # English-only literals are only interesting inside UI constructors
            ui = bool(UI_CTX.search(line))
            log = bool(LOG_CTX.search(line))
            if has_cjk:
                kind = 'log' if log else ('ui' if ui else 'other')
                rows.append((rel, idx + 1, kind, text[:70]))
            elif ui and re.search(r'[A-Za-z]{3}', text) and not re.match(r'^[a-z_0-9.:/-]+$', text):
                rows.append((rel, idx + 1, 'ui-en', text[:70]))

counts = {}
for rel, _, kind, _ in rows:
    counts.setdefault(rel, [0, 0, 0, 0])
    c = counts[rel]
    c[0] += 1
    if kind == 'ui':
        c[1] += 1
    elif kind == 'ui-en':
        c[2] += 1
    elif kind == 'log':
        c[3] += 1

print('total flagged literals:', len(rows))
for rel, c in sorted(counts.items(), key=lambda kv: -kv[1][0])[:40]:
    print(f'{c[0]:4d}  ui={c[1]:3d} en={c[2]:3d} log={c[3]:3d}  {rel}')
if len(sys.argv) > 1 and sys.argv[1] == '--dump':
    target = sys.argv[2]
    for rel, ln, kind, text in rows:
        if rel.endswith(target):
            print(f'{kind:6s} {rel}:{ln}  {text}')
