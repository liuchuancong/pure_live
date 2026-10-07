import re
from pathlib import Path


# =========================
# 配置
# =========================

# 要扫描的目录
ROOT_DIR = Path(__file__).resolve().parent.parent

# 是否自动修改文件
AUTO_FIX = True

# 是否打印已经存在 physics 的 ListView
SHOW_OK = False


# =========================
# ListView 检查
# =========================

def find_listview_end(text: str, start: int):
    """
    从 ListView( 的位置开始，找到对应的结束括号 )。
    支持：
      ListView(...)
      ListView.builder(...)
      ListView.separated(...)
      ListView.custom(...)
    """

    # 找到第一个 (
    open_paren = text.find("(", start)
    if open_paren == -1:
        return None

    depth = 0
    in_string = None
    escape = False

    i = open_paren

    while i < len(text):
        char = text[i]

        # 处理字符串
        if in_string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == in_string:
                in_string = None

            i += 1
            continue

        # 字符串开始
        if char in ("'", '"'):
            in_string = char
            i += 1
            continue

        # 单行注释
        if char == "/" and i + 1 < len(text) and text[i + 1] == "/":
            newline = text.find("\n", i + 2)
            if newline == -1:
                return None
            i = newline
            continue

        # 多行注释
        if char == "/" and i + 1 < len(text) and text[i + 1] == "*":
            end_comment = text.find("*/", i + 2)
            if end_comment == -1:
                return None
            i = end_comment + 2
            continue

        if char == "(":
            depth += 1

        elif char == ")":
            depth -= 1

            if depth == 0:
                return i

        i += 1

    return None


def get_line_indent(text: str, position: int) -> str:
    """获取指定位置所在行的缩进"""

    line_start = text.rfind("\n", 0, position) + 1
    line = text[line_start:position]

    match = re.match(r"[ \t]*", line)
    return match.group(0) if match else ""


def process_file(path: Path):
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        try:
            text = path.read_text(encoding="utf-8-sig")
        except Exception as e:
            print(f"[跳过] {path}：{e}")
            return 0, 0

    original_text = text

    # 匹配：
    #
    # ListView(
    # ListView.builder(
    # ListView.separated(
    # ListView.custom(
    #
    pattern = re.compile(
        r"\bListView(?:\.(?:builder|separated|custom))?\s*\("
    )

    matches = list(pattern.finditer(text))

    if not matches:
        return 0, 0

    added_count = 0
    existing_count = 0

    # 从后往前修改，避免位置偏移
    modifications = []

    for match in reversed(matches):
        start = match.start()

        end = find_listview_end(text, start)

        if end is None:
            print(f"[警告] 无法找到 ListView 结束位置：{path}")
            continue

        content = text[match.end():end]

        # 已经有 physics:
        #
        # physics: xxx
        #
        # 注意：
        # 这里不是只检查 PureLiveScrollPhysics，
        # 而是只要已经存在 physics 就不自动覆盖。
        physics_pattern = re.compile(
            r"\bphysics\s*:"
        )

        if physics_pattern.search(content):
            existing_count += 1

            if SHOW_OK:
                line = text.count("\n", 0, start) + 1
                print(
                    f"[OK] {path}:{line} "
                    f"已有 physics"
                )

            continue

        # ListView 的结束位置
        #
        # 找最后一个参数的位置，在最后一个参数后面插入 physics。
        #
        # 如果：
        #
        # ListView(
        #   children: [
        #   ],
        # )
        #
        # 变成：
        #
        # ListView(
        #   children: [
        #   ],
        #   physics: const PureLiveScrollPhysics(),
        # )
        #
        close_paren = end

        # 获取 ListView(...) 内最后一行的缩进
        line_start = text.rfind("\n", match.start(), close_paren) + 1
        current_line = text[line_start:close_paren]

        # 尝试找到 ListView 参数的缩进
        indent_match = re.match(r"[ \t]*", current_line)

        if indent_match:
            base_indent = indent_match.group(0)
        else:
            base_indent = ""

        # 如果内容为空
        if not content.strip():
            insert = (
                "\n"
                + base_indent
                + "  physics: const PureLiveScrollPhysics(),\n"
            )

        else:
            # 判断最后一个非空字符是不是逗号
            stripped = content.rstrip()

            if stripped.endswith(","):
                insert = (
                    "\n"
                    + base_indent
                    + "  physics: const PureLiveScrollPhysics(),"
                )
            else:
                insert = (
                    ",\n"
                    + base_indent
                    + "  physics: const PureLiveScrollPhysics(),"
                )

        modifications.append((close_paren, insert))

        added_count += 1

    # 应用修改
    for position, insert in modifications:
        text = text[:position] + insert + text[position:]

    if text != original_text:
        if AUTO_FIX:
            path.write_text(text, encoding="utf-8")
            print(
                f"[修改] {path} "
                f"→ 添加 {added_count} 个 PureLiveScrollPhysics"
            )
        else:
            print(
                f"[发现] {path} "
                f"→ 可以添加 {added_count} 个 PureLiveScrollPhysics"
            )

    return added_count, existing_count


# =========================
# 主程序
# =========================

def main():
    if not ROOT_DIR.exists():
        print(f"[错误] 目录不存在：{ROOT_DIR}")
        return

    dart_files = list(ROOT_DIR.rglob("*.dart"))

    # 排除常见目录
    dart_files = [
        path
        for path in dart_files
        if not any(
            part in {
                ".dart_tool",
                "build",
                ".git",
            }
            for part in path.parts
        )
    ]

    print("=" * 70)
    print("PureLive ListView physics 检查")
    print("=" * 70)
    print(f"扫描目录：{ROOT_DIR}")
    print(f"Dart 文件：{len(dart_files)}")
    print(f"自动修改：{'是' if AUTO_FIX else '否'}")
    print("=" * 70)

    total_added = 0
    total_existing = 0
    changed_files = 0

    for path in dart_files:
        added, existing = process_file(path)

        total_added += added
        total_existing += existing

        if added > 0:
            changed_files += 1

    print()
    print("=" * 70)
    print("检查完成")
    print("=" * 70)
    print(f"检查文件：{len(dart_files)}")
    print(f"修改文件：{changed_files}")
    print(f"新增 physics：{total_added}")
    print(f"已有 physics：{total_existing}")
    print("=" * 70)


if __name__ == "__main__":
    main()