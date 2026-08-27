import re
import subprocess
from pathlib import Path

WORKFLOW = Path(".github/workflows/build_pure_live_release.yml")

USES_PATTERN = re.compile(
    r"^(\s*uses:\s*)([^@\s]+)@([^\s#]+)(.*)$"
)

VERSION_PATTERN = re.compile(
    r"#\s*(v[0-9][^\s]*)"
)

SHA_PATTERN = re.compile(
    r"^[0-9a-fA-F]{40}$"
)

def git_ls_remote(repo, ref):
    result = subprocess.run(
        [
            "git",
            "ls-remote",
            f"https://github.com/{repo}.git",
            ref,
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        return None

    lines = result.stdout.strip().splitlines()

    if not lines:
        return None

    return lines[0].split()[0]

def get_tag_sha(repo, version):
    sha = git_ls_remote(
        repo,
        f"refs/tags/{version}",
    )

    if sha:
        return sha

    sha = git_ls_remote(
        repo,
        f"refs/tags/{version}^{{}}",
    )

    if sha:
        return sha

    return None

def get_sha_tags(repo, sha):
    result = subprocess.run(
        [
            "git",
            "ls-remote",
            "--tags",
            f"https://github.com/{repo}.git",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        return []

    result_list = []

    for line in result.stdout.splitlines():
        parts = line.split()

        if len(parts) != 2:
            continue

        tag_sha, ref = parts

        if tag_sha.lower() != sha.lower():
            continue

        if not ref.startswith("refs/tags/"):
            continue

        tag = ref[len("refs/tags/"):]

        if tag.endswith("^{}"):
            tag = tag[:-3]

        result_list.append(tag)

    return result_list

def extract_version(comment):
    match = VERSION_PATTERN.search(comment)

    if match:
        return match.group(1)

    return None

def main():
    if not WORKFLOW.exists():
        raise FileNotFoundError(
            f"找不到 workflow: {WORKFLOW}"
        )

    text = WORKFLOW.read_text(
        encoding="utf-8"
    )

    lines = text.splitlines(
        keepends=True
    )

    cache = {}

    changed = 0

    for index, line in enumerate(lines):
        if line.endswith("\r\n"):
            content = line[:-2]
            newline = "\r\n"
        elif line.endswith("\n"):
            content = line[:-1]
            newline = "\n"
        else:
            content = line
            newline = ""

        match = USES_PATTERN.match(content)

        if not match:
            continue

        prefix = match.group(1)
        repo = match.group(2)
        reference = match.group(3)
        suffix = match.group(4)

        if not SHA_PATTERN.fullmatch(reference):
            continue

        key = f"{repo}@{reference}"

        if key not in cache:
            print(
                f"查询 {repo}@{reference}"
            )

            tags = get_sha_tags(
                repo,
                reference,
            )

            cache[key] = tags

        tags = cache[key]

        version = None

        if tags:
            version = tags[0]

        if not version:
            version = extract_version(
                suffix
            )

        if not version:
            print(
                f"无法确定版本: "
                f"{repo}@{reference}"
            )
            continue

        real_sha = get_tag_sha(
            repo,
            version,
        )

        if not real_sha:
            print(
                f"无法获取版本 SHA: "
                f"{repo}@{version}"
            )
            continue

        new_line = (
            f"{prefix}"
            f"{repo}@{real_sha}"
            f" # {version}"
            f"{newline}"
        )

        if content != new_line.rstrip("\r\n"):
            lines[index] = new_line

            print(
                f"更新: "
                f"{repo}@{reference}"
                f" -> "
                f"{repo}@{real_sha}"
                f" # {version}"
            )

            changed += 1

    WORKFLOW.write_text(
        "".join(lines),
        encoding="utf-8",
    )

    print(
        f"完成，共更新 {changed} 个 Action。"
    )

if __name__ == "__main__":
    main()