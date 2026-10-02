"""Add explicit imports for symbols that were previously reachable through the
lib/core/index.dart barrel. Iterates the analyzer until it converges.

Scratch helper for the layering migration; not part of the build.
"""
import collections
import json
import pathlib
import re
import subprocess

LIB = pathlib.Path('lib')
FLUTTERW = 'tool/flutterw.ps1'

DECL = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*"
    r"(?:class|enum|mixin|extension|typedef)\s+(?=[A-Z])([A-Za-z_0-9]+)"
)
FUNC = re.compile(r"^(?:[A-Za-z_][\w<>,?\s]*\s+)?([a-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*\([^;]*\)\s*(?:async)?\s*[{=]")
VAR = re.compile(r"^(?:const|final)\s+(?:[A-Za-z_][\w<>,?\s]*\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=")

ERR = re.compile(r"(?:Undefined (?:name|class|getter|function)|The (?:method|function|name) '([A-Za-z_0-9]+)' isn't|"
                 r"The name '([A-Za-z_0-9]+)' isn't a type|Undefined name '([A-Za-z_0-9]+)'|"
                 r"Undefined class '([A-Za-z_0-9]+)')")


def build_index():
    idx = collections.defaultdict(list)
    for p in LIB.rglob('*.dart'):
        if p.parts[1] == 'get':
            continue
        text = p.read_text(encoding='utf-8', errors='replace')
        rel = p.relative_to(LIB).as_posix()
        for line in text.split('\n'):
            for rx in (DECL, VAR):
                m = rx.match(line)
                if m:
                    idx[m.group(1)].append(rel)
            m = FUNC.match(line)
            if m and not line.startswith('  '):
                idx[m.group(1)].append(rel)
            m = re.match(r"^(\w+)\s+get\s+([A-Za-z_0-9]+)", line)
            if m:
                idx[m.group(2)].append(rel)
    return {k: sorted(set(v)) for k, v in idx.items()}


def analyze():
    out = subprocess.run(
        ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', FLUTTERW, 'analyze'],
        capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
    return out


def errors(out):
    res = []
    for line in out.splitlines():
        m = re.match(r"\s*error - (.*?) - (\S+\.dart):(\d+):\d+ - (\w+)", line)
        if not m:
            continue
        message, fpath, ln, rule = m.group(1), m.group(2), int(m.group(3)), m.group(4)
        # the offending identifier is the first quoted token that is a known symbol
        cands = re.findall(r"'([A-Za-z_][A-Za-z0-9_]*)'", message)
        sym = next((c for c in cands if c in index and c != 'pure_live'), None)
        if sym is None:
            sym = cands[0] if cands else None
        rel = pathlib.PureWindowsPath(fpath).as_posix()
        rel = rel.split('lib/')[-1] if 'lib/' in rel else rel
        res.append((rel, ln, rule, [sym] if sym else []))
    return res


def snake(name):
    s = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s).lower()


def add_import(file_rel, target_rel):
    p = LIB / file_rel
    text = p.read_text(encoding='utf-8')
    uri = "import 'package:pure_live/%s';" % target_rel
    if uri in text:
        return False
    lines = text.split('\n')
    last = max([i for i, l in enumerate(lines) if l.startswith('import ')] or [0])
    lines.insert(last + 1, uri)
    p.write_text('\n'.join(lines), encoding='utf-8')
    return True


index = build_index()
unresolved = collections.Counter()
for round_no in range(1, 12):
    out = analyze()
    errs = errors(out)
    if not errs:
        print('converged after', round_no - 1, 'rounds')
        break
    touched = 0
    for rel, ln, rule, names in errs:
        sym = names[0] if names else None
        if not sym:
            unresolved[rule] += 1
            continue
        cands = [c for c in index.get(sym, []) if c != rel]
        if not cands:
            unresolved['%s:%s' % (rule, sym)] += 1
            continue
        best = None
        if len(cands) == 1:
            best = cands[0]
        else:
            match = [c for c in cands if pathlib.PurePosixPath(c).stem == snake(sym)]
            best = match[0] if match else cands[0]
        if add_import(rel, best):
            touched += 1
    print('round', round_no, 'errors', len(errs), 'imports added', touched)
    if touched == 0:
        print('stuck; unresolved symbols:', json.dumps(dict(unresolved.most_common(20)), ensure_ascii=False))
        break
print('final analyze:')
print(analyze().strip().splitlines()[-1])
if unresolved:
    print('unresolved:', dict(unresolved.most_common(15)))
