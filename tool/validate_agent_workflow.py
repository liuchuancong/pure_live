"""Static instruction/workflow checks. No builds, network or device access.

Requires developer-side PyYAML; not an application/runtime dependency.
"""
import copy
from pathlib import Path
import re
import sys
import tomllib

import yaml


class Loader(yaml.SafeLoader):
    # GitHub uses YAML 1.2: `on` is a key, not the YAML 1.1 boolean True.
    yaml_implicit_resolvers = copy.deepcopy(yaml.SafeLoader.yaml_implicit_resolvers)


for char, rules in Loader.yaml_implicit_resolvers.items():
    Loader.yaml_implicit_resolvers[char] = [r for r in rules if r[0] != 'tag:yaml.org,2002:bool']
Loader.add_implicit_resolver('tag:yaml.org,2002:bool', re.compile(r'^(?:true|false)$', re.I), list('tTfF'))


def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f'duplicate YAML key: {key}')
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


Loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)


def check_workflows(workflows):
    errors = []
    tag_owners = {}
    for name, doc in workflows.items():
        events = doc.get('on', {})
        if 'pull_request_target' in events:
            errors.append(f'{name}: unexpected privileged PR trigger')
        if doc.get('permissions') == 'write-all':
            errors.append(f'{name}: broad permissions')
        push = events.get('push') or {}
        dispatch_inputs = (events.get('workflow_dispatch') or {}).get('inputs', {})
        for tag in push.get('tags', []):
            tag_owners.setdefault(tag, []).append(name)
        jobs = doc.get('jobs', {})
        for job, body in jobs.items():
            needs = body.get('needs', [])
            needs = [needs] if isinstance(needs, str) else needs
            if any(dependency not in jobs or dependency == job for dependency in needs):
                errors.append(f'{name}/{job}: invalid job dependency')
            if not isinstance(body.get('timeout-minutes'), int):
                errors.append(f'{name}/{job}: explicit timeout required')
            for step in body.get('steps', []):
                uses = step.get('uses', '')
                if uses and not uses.startswith('./') and not re.fullmatch(r'[^@]+@[0-9a-f]{40}', uses):
                    errors.append(f'{name}/{job}: mutable external Action {uses}')
                script = step.get('run', '')
                for key in re.findall(r'\$\{\{\s*inputs\.(\w+)\s*\}\}', script):
                    if dispatch_inputs.get(key, {}).get('type', 'string') == 'string':
                        errors.append(f'{name}/{job}: string input {key} embedded in script; use env')
                if re.search(r'\$\{\{[^\n]*\.version_desc\s*\}\}', script):
                    errors.append(f'{name}/{job}: release description embedded in script; use env')
        visited, visiting = set(), set()

        def visit(job):
            if job in visiting:
                errors.append(f'{name}: cyclic jobs at {job}')
                return
            if job in visited or job not in jobs:
                return
            visiting.add(job)
            dependencies = jobs[job].get('needs', [])
            for dependency in [dependencies] if isinstance(dependencies, str) else dependencies:
                visit(dependency)
            visiting.remove(job)
            visited.add(job)

        for job in jobs:
            visit(job)
    for tag in ('stage-linux-*', 'stage-macos-*', 'stage-ios-*'):
        if tag_owners.get(tag) != ['feature-build.yml']:
            errors.append(f'{tag}: must have one owner, feature-build.yml')
    for name in ('feature-build.yml', 'build_pure_live_release.yml'):
        doc = workflows[name]
        if doc.get('concurrency', {}).get('cancel-in-progress') is not False:
            errors.append(f'{name}: shared build group must not cancel another run')
        inputs = doc['on']['workflow_dispatch']['inputs']
        for key, value in inputs.items():
            if value.get('type') == 'boolean' and value.get('default') is not False:
                errors.append(f'{name}: {key} unexpectedly defaults on')
        for job, dependencies in {
            'windows': ['android'], 'linux': ['android', 'windows'],
            'apple': ['android', 'windows', 'linux'],
            'publish-release': ['android', 'windows', 'linux', 'apple'],
        }.items():
            body = doc['jobs'][job]
            condition = ' '.join(str(body.get('if', '')).split())
            for dependency in dependencies:
                selector = '(inputs.build_macos || inputs.build_ios)' if dependency == 'apple' else f'inputs.build_{dependency}'
                if dependency not in body.get('needs', []):
                    errors.append(f'{name}/{job}: missing direct dependency {dependency}')
                if f'!{selector} || needs.{dependency}.result == \'success\'' not in condition:
                    errors.append(f'{name}/{job}: selected {dependency} failure may pass')
            if job == 'publish-release' and '(inputs.build_android || inputs.build_windows || inputs.build_linux || inputs.build_macos || inputs.build_ios)' not in condition:
                errors.append(f'{name}: empty platform selection may publish')
    return errors


def main():
    root = Path(__file__).resolve().parent.parent
    errors = []
    entries = [root / 'AGENTS.md', root / 'CLAUDE.md', root / 'docs/AGENT_WORKFLOW.md']
    entries += sorted((root / '.agents/skills').glob('*/SKILL.md'))
    for path in entries:
        text = path.read_text(encoding='utf-8-sig')
        if path.name == 'SKILL.md':
            frontmatter = text.split('---', 2)
            if len(frontmatter) != 3 or frontmatter[0].strip():
                errors.append(f'{path}: missing frontmatter')
            else:
                metadata = yaml.load(frontmatter[1], Loader=Loader)
                if metadata.get('name') != path.parent.name or not metadata.get('description'):
                    errors.append(f'{path}: skill discovery metadata')
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
            if re.match(r'^[a-zA-Z]+:', target) or target.startswith('#'):
                continue
            if not (path.parent / target.split('#')[0]).is_file():
                errors.append(f'{path.relative_to(root)}: broken link {target}')
    model_policy_owner = root / 'docs/AGENT_WORKFLOW.md'
    model_policy_keyword = 'Astra Light'
    active_documents = [
        root / 'AGENTS.md',
        root / 'BUILD_POLICY.md',
        root / 'MAINTENANCE_POLICY.md',
        root / 'README.md',
        root / 'docs/ACCEPTANCE_3_2_0.md',
        root / 'docs/ACCEPTANCE_STATUS_3_2_0.md',
        root / 'docs/ACCEPTANCE_MATRIX_3_1_0.md',
        root / 'docs/ISSUE_TRIAGE_LEDGER_3_2_0.md',
    ]
    if model_policy_keyword not in model_policy_owner.read_text(encoding='utf-8-sig'):
        errors.append('docs/AGENT_WORKFLOW.md: missing centralized Windows GUI model/cost rule')
    for path in active_documents:
        if model_policy_keyword in path.read_text(encoding='utf-8-sig'):
            errors.append(
                f'{path.relative_to(root)}: duplicate Windows GUI model/cost rule; link to docs/AGENT_WORKFLOW.md'
            )
    readme = (root / 'README.md').read_text(encoding='utf-8-sig')
    status_owner = '<!-- current-status-owner: docs/ACCEPTANCE_STATUS_3_2_0.md -->'
    if readme.count(status_owner) != 1:
        errors.append('README.md: current acceptance status must have one authoritative-owner marker')
    for stale_label in ('源码未发布', '定向候选，未发布'):
        if stale_label in readme:
            errors.append(f'README.md: mutable batch status belongs in the acceptance ledgers: {stale_label}')
    index_start = '<!-- stable-doc-index:start -->'
    index_end = '<!-- stable-doc-index:end -->'
    if readme.count(index_start) != 1 or readme.count(index_end) != 1:
        errors.append('README.md: stable document index markers must appear exactly once')
    else:
        index = readme.split(index_start, 1)[1].split(index_end, 1)[0]
        if len(re.findall(r'(?m)^\| \[', index)) > 18:
            errors.append('README.md: stable document index is becoming a historical audit catalog')
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', index):
            if not (root / target.split('#')[0]).is_file():
                errors.append(f'README.md: broken stable document link {target}')
    workflows = {
        p.name: yaml.load(p.read_text(encoding='utf-8-sig'), Loader=Loader)
        for p in sorted((root / '.github/workflows').glob('*.yml'))
    }
    errors += check_workflows(workflows)
    environment = tomllib.loads((root / '.codex/environments/environment.toml').read_text(encoding='utf-8-sig'))
    if environment.get('setup', {}).get('script', '').strip():
        errors.append('workspace setup must stay lazy; use the scoped build gate')
    # Negative controls exercise structural rules rather than accepting a file
    # merely because it contains policy marker comments.
    duplicate = copy.deepcopy(workflows)
    duplicate['build-ios-unsigned.yml']['on']['push'] = {'tags': ['stage-ios-*']}
    missing_guard = copy.deepcopy(workflows)
    missing_guard['feature-build.yml']['jobs']['linux']['if'] = '${{ always() }}'
    script_input = copy.deepcopy(workflows)
    script_input['feature-build.yml']['jobs']['publish-release']['steps'].append({
        'run': 'echo "${{ inputs.release_tag }}"',
    })
    release_text = copy.deepcopy(workflows)
    release_text['feature-build.yml']['jobs']['publish-release']['steps'].append({
        'run': "cat <<'EOF'\n${{ fromJson(steps.version.outputs.content).version_desc }}\nEOF",
    })
    controls = (duplicate, missing_guard, script_input, release_text)
    if not all(check_workflows(control) for control in controls):
        errors.append('validator negative controls failed')
    for error in errors:
        print(f'ERROR {error}')
    print(f'Agent/workflow static audit: {len(entries)} instruction files, {len(workflows)} workflows, {len(errors)} errors; {len(controls)} negative controls checked.')
    return bool(errors)


if __name__ == '__main__':
    sys.exit(main())
