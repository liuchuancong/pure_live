"""Architecture dependency checker for the App / Core / Domains / Features layering.

Rules (see the layering model agreed for this project):

  app       -> core, domains, features          (装配与路由，不含业务实现)
  core      -> (nothing above)                  (平台基础设施，完全脱离业务)
  domains/X -> core, domains/X                  (域内自包含；禁止依赖别的域)
  features  -> core, domains                    (轻量页面，复用域能力)

Within a domain: presentation -> domain (abstractions), data -> domain (abstractions).
`presentation -> data` is reported as a soft finding: it works, but the page should
talk to the domain abstraction and let the repository implementation be injected.

Usage:
    python tool/validate_architecture.py              # summary + findings
    python tool/validate_architecture.py --strict     # exit 1 on any hard violation

Baseline exceptions live in BASELINE below: they are known, still-unmigrated
couplings. Fix the code and delete the line - never add to this list casually.
"""

from __future__ import annotations

import pathlib
import re
import sys

LIB = pathlib.Path('lib')
LAYERS = ('app', 'core', 'domains', 'features', 'player', 'services')

# Known remaining couplings: (source file, target package prefix). Remove as they get fixed.
BASELINE: set[tuple[str, str]] = set()

IMPORT_RE = re.compile(r"""^\s*(?:import|export)\s+'package:pure_live/([A-Za-z0-9_/.-]+)\.dart'""")
RELATIVE_RE = re.compile(r"""^\s*(?:import|export)\s+'([./][A-Za-z0-9_/.-]+\.dart)'""")


def layer_of(path: pathlib.PurePosixPath) -> tuple[str, str | None]:
    """(layer, domain) for a lib-relative path."""
    parts = path.parts
    if parts[0] == 'domains' and len(parts) >= 2:
        return 'domains', parts[1]
    return parts[0], None


def resolve_relative(source: pathlib.PurePosixPath, uri: str) -> pathlib.PurePosixPath:
    joined = (source.parent / uri)
    out: list[str] = []
    for part in joined.parts:
        if part == '..':
            if out:
                out.pop()
        elif part != '.':
            out.append(part)
    return pathlib.PurePosixPath(*out)


def target_of(source: pathlib.PurePosixPath, line: str) -> pathlib.PurePosixPath | None:
    m = IMPORT_RE.match(line)
    if m:
        return pathlib.PurePosixPath(m.group(1) + '.dart')
    m = RELATIVE_RE.match(line)
    if m:
        return resolve_relative(source, m.group(1))
    return None


def tier_of(target: pathlib.PurePosixPath) -> tuple[str, str | None]:
    return layer_of(target)


def layer_role(path: pathlib.PurePosixPath) -> str | None:
    """data / domain / presentation inside a domain, else None."""
    parts = path.parts
    if len(parts) >= 3 and parts[0] == 'domains':
        role = parts[2]
        if role in ('data', 'domain', 'presentation'):
            return role
    return None


def main() -> int:
    strict = '--strict' in sys.argv
    hard: list[str] = []
    soft: list[str] = []
    baselined = 0

    for file in sorted(LIB.rglob('*.dart')):
        rel = file.relative_to(LIB).as_posix()
        parts = pathlib.PurePosixPath(rel).parts
        if parts[0] == 'get':
            continue
        source_layer, source_domain = layer_of(pathlib.PurePosixPath(rel))
        source_role = layer_role(pathlib.PurePosixPath(rel))
        text = file.read_text(encoding='utf-8', errors='replace')

        for line in text.splitlines():
            target = target_of(pathlib.PurePosixPath(rel), line)
            if target is None:
                continue
            target_layer, target_domain = tier_of(target)
            if target_layer not in LAYERS:
                continue
            key = (rel, f'{target_layer}/{target_domain or "-"}')

            # core must not know about anything above it
            if source_layer == 'core' and target_layer in ('app', 'domains', 'features', 'services'):
                hard.append(f'core -> {target.as_posix()}   [{rel}]')
            # app may depend on everything, features on core+domains, domains on core + itself
            if source_layer == 'features' and target_layer == 'app':
                hard.append(f'features -> app   [{rel}]')
            if source_layer == 'domains' and target_layer == 'domains' and target_domain != source_domain:
                hard.append(f'domains/{source_domain} -> domains/{target_domain}   [{rel}]')
            if source_layer == 'domains' and target_layer == 'features':
                hard.append(f'domains/{source_domain} -> features   [{rel}]')

            # intra-domain direction: presentation and data lean on domain, not on each other
            if (
                source_layer == 'domains'
                and target_layer == 'domains'
                and target_domain == source_domain
                and source_role
                and (role := layer_role(target))
            ):
                if source_role == 'data' and role == 'presentation':
                    hard.append(f'data -> presentation   [{rel}]')
                elif source_role == 'presentation' and role == 'data':
                    soft.append(f'presentation -> data   [{rel}]')

    for finding in list(hard) + list(soft):
        marker = finding.split('   ')[0]
        rel = finding.split('[')[-1].rstrip(']')
        target_layer = marker.split(' -> ')[1]
        if (rel, f'{target_layer}/-') in BASELINE or any(rel == b[0] for b in BASELINE):
            baselined += 1
            continue
        print(finding)

    print(f'\nhard violations: {len(hard)}   soft findings: {len(soft)}   baseline-ignored: {baselined}')
    if strict and hard:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
