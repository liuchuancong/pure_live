"""Architecture dependency checker for the App / Core / Shared / Domains / Features layering.

Rules (see the layering model agreed for this project):

  app       -> core, shared, domains, features   (装配与路由，不含业务实现)
  core      -> (nothing above)                   (平台基础设施，完全脱离业务)
  shared    -> core, shared                      (跨域共享基底：站点适配器与平台契约)
  domains/X -> core, shared, domains/X           (域内自包含；禁止依赖别的域)
  features  -> core, shared, domains             (轻量页面，复用域能力)

The shared layer exists because playback, recording and account all use the same
site adapters and the same platform contract. Domains may only depend on Core, so
without a shared layer those uses can only be expressed as forbidden domain ->
domain edges.

Within a domain: presentation -> domain (abstractions), data -> domain (abstractions).
`presentation -> data` is reported as a soft finding: it works, but the page should
talk to the domain abstraction and let the repository implementation be injected.

Usage:
    python tool/validate_architecture.py                   # hard findings not yet approved
    python tool/validate_architecture.py --strict          # exit 1 on any hard violation
    python tool/validate_architecture.py --soft            # also list presentation->data advisories
    python tool/validate_architecture.py --list-baseline   # print the ledger literal to paste back

BASELINE below is the approved-exception ledger: it lists the exact couplings that
are known and still unmigrated, so the checker can gate new ones in CI while the
shared-layer migration proceeds. One finding is one line. Fix the coupling, run
--list-baseline, and delete that line - never add to this list casually.
A ledger line whose coupling no longer exists is "stale" and also fails --strict,
so the ledger cannot rot into blanket cover for a reintroduced coupling.
"""

from __future__ import annotations

import pathlib
import re
import sys

LIB = pathlib.Path('lib')
LAYERS = ('app', 'core', 'shared', 'domains', 'features')

# Approved exceptions: exact finding strings ("<source layer> -> <target path>   [<source file>]").
BASELINE: frozenset[str] = frozenset({
    'core -> domains/live/data/platforms/sites.dart   [core/navigation/app_navigator.dart]',
    'core -> domains/live/domain/global_player_service.dart   [core/navigation/app_navigator.dart]',
    'core -> domains/live/domain/global_player_service.dart   [core/platform/desktop_manager.dart]',
    'core -> domains/live/domain/global_player_service.dart   [core/player/kernel/player_kernel_service.dart]',
    'core -> domains/live/domain/live_player_facade.dart   [core/player/kernel/floating_playback.dart]',
    'domains/account -> domains/live/data/favorite_room_controller.dart   [domains/account/presentation/auth/auth_controller.dart]',
    'domains/account -> domains/live/presentation/favorite/favorite_controller.dart   [domains/account/presentation/auth/utils/firebase_manager.dart]',
    'domains/account -> features/backup/backup_controller.dart   [domains/account/presentation/auth/utils/firebase_manager.dart]',
    'domains/iptv -> domains/live/data/favorite_room_controller.dart   [domains/iptv/data/iptv_settings_controller.dart]',
    'domains/live -> domains/iptv/data/iptv_settings_controller.dart   [domains/live/data/playback_header_resolver.dart]',
    'domains/live -> domains/iptv/data/iptv_settings_controller.dart   [domains/live/presentation/playback/widgets/video_player/video_controller.dart]',
    'domains/live -> domains/iptv/data/local/database.dart   [domains/live/presentation/playback/widgets/video_player/iptv_schedule_dialog.dart]',
    'domains/live -> domains/iptv/data/local/database.dart   [domains/live/presentation/playback/widgets/video_player/video_controller.dart]',
    'domains/live -> domains/iptv/data/local/db_service.dart   [domains/live/presentation/playback/widgets/video_player/video_controller.dart]',
    'domains/live -> domains/iptv/data/platforms/iptv_site.dart   [domains/live/data/platforms/sites.dart]',
    'domains/live -> domains/recorder/data/services/ffmpeg_hls_input_relay.dart   [domains/live/data/stream/playback_source_transport.dart]',
    'domains/live -> domains/recorder/presentation/pages/recorder/recorder_controller.dart   [domains/live/presentation/playback/controllers/live_play_controller.dart]',
    'domains/live -> domains/recorder/presentation/widgets/record_action_button.dart   [domains/live/presentation/playback/widgets/layout/live_play_header.dart]',
    'domains/recorder -> domains/live/data/platforms/sites.dart   [domains/recorder/data/services/stream_resolver_service.dart]',
    'domains/recorder -> domains/live/data/platforms/sites.dart   [domains/recorder/presentation/pages/recorder/recorder_controller.dart]',
    'domains/recorder -> domains/live/data/playback_header_resolver.dart   [domains/recorder/data/services/ffmpeg_header_factory.dart]',
})

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


def collect() -> tuple[list[str], list[str]]:
    hard: list[str] = []
    soft: list[str] = []

    for file in sorted(LIB.rglob('*.dart')):
        rel = file.relative_to(LIB).as_posix()
        parts = pathlib.PurePosixPath(rel).parts
        if parts[0] == 'get':
            continue
        source_layer, source_domain = layer_of(pathlib.PurePosixPath(rel))
        source_role = layer_role(pathlib.PurePosixPath(rel))
        # utf-8-sig so a byte-order mark cannot hide a file's first import from
        # the `^\s*import` match (which silently skipped the whole line).
        text = file.read_text(encoding='utf-8-sig', errors='replace')

        for line in text.splitlines():
            target = target_of(pathlib.PurePosixPath(rel), line)
            if target is None:
                continue
            target_layer, target_domain = tier_of(target)
            if target_layer not in LAYERS:
                continue

            # core and shared must not know about anything above them
            if source_layer in ('core', 'shared') and target_layer in ('app', 'domains', 'features'):
                hard.append(f'{source_layer} -> {target.as_posix()}   [{rel}]')
            # shared sits above core, so core must not reach into it either
            if source_layer == 'core' and target_layer == 'shared':
                hard.append(f'core -> {target.as_posix()}   [{rel}]')

            # everything above may depend on everything below
            if source_layer == 'features' and target_layer == 'app':
                hard.append(f'features -> {target.as_posix()}   [{rel}]')
            if source_layer == 'domains' and target_layer == 'domains' and target_domain != source_domain:
                hard.append(f'domains/{source_domain} -> {target.as_posix()}   [{rel}]')
            if source_layer == 'domains' and target_layer == 'features':
                hard.append(f'domains/{source_domain} -> {target.as_posix()}   [{rel}]')
            if source_layer == 'domains' and target_layer == 'app':
                hard.append(f'domains/{source_domain} -> {target.as_posix()}   [{rel}]')

            # intra-domain direction: presentation and data lean on domain, not on each other
            if (
                source_layer == 'domains'
                and target_layer == 'domains'
                and target_domain == source_domain
                and source_role
                and (role := layer_role(target))
            ):
                if source_role == 'data' and role == 'presentation':
                    hard.append(f'data -> {target.as_posix()}   [{rel}]')
                elif source_role == 'presentation' and role == 'data':
                    soft.append(f'presentation -> {target.as_posix()}   [{rel}]')

    return hard, soft


def main() -> int:
    strict = '--strict' in sys.argv
    show_soft = '--soft' in sys.argv
    list_baseline = '--list-baseline' in sys.argv

    hard, soft = collect()
    unknown_hard = [f for f in hard if f not in BASELINE]
    baselined = len(hard) - len(unknown_hard)
    # A ledger line whose coupling no longer exists must be deleted, otherwise the
    # ledger silently rots and later re-introduces the coupling unnoticed.
    stale = sorted(BASELINE - set(hard))

    if list_baseline:
        print('BASELINE: frozenset[str] = frozenset({')
        for finding in sorted(set(hard)):
            print(f'    {finding!r},')
        print('})')
        return 0

    for finding in unknown_hard:
        print(finding)

    if stale:
        print('\nstale BASELINE entries (coupling already fixed - delete these lines):')
        for finding in stale:
            print(f'  {finding}')

    if show_soft:
        for finding in soft:
            print(finding)

    print(
        f'\nhard violations: {len(unknown_hard)} unapproved + {baselined} approved'
        f'   stale ledger entries: {len(stale)}   soft advisories: {len(soft)}'
    )
    if strict and (unknown_hard or stale):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
