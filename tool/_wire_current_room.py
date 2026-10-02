import io
import pathlib

CAND = "package:pure_live/domains/live/presentation/playback/controllers/player_controller.dart"


def read(p):
    with io.open(p, 'r', encoding='utf-8', newline='') as f:
        return f.read()


def write(p, t):
    with io.open(p, 'w', encoding='utf-8', newline='') as f:
        f.write(t)


def add_import(t, uri):
    if uri in t:
        return t
    lines = t.split('\n')
    last = max([i for i, l in enumerate(lines) if l.startswith('import ')] or [0])
    lines.insert(last + 1, "import '%s';" % uri)
    return '\n'.join(lines)


# 1) presentation 层挂载 provider
p = pathlib.Path('lib/domains/live/presentation/playback/controllers/player_controller.dart')
t = read(p)
if 'CurrentLiveRoom.provider' not in t:
    nl = '\r\n' if '\r\n' in t else '\n'
    comment = '    // 站点适配器只需只读地知道当前在播的房间，由这里挂载，data 层不再找页面控制器。'
    init = nl.join([
        '  @override',
        '  void onInit() {',
        comment,
        '    CurrentLiveRoom.provider = () => currentRoom;',
        '    super.onInit();',
        '  }',
        '',
    ])
    anchor = '  void onClose() {'
    idx = t.index(anchor)
    t = t[:idx] + init + t[idx:]
    t = t.replace(anchor + nl, anchor + nl + '    CurrentLiveRoom.provider = null;' + nl, 1)
    t = add_import(t, 'package:pure_live/domains/live/domain/current_live_room.dart')
    write(p, t)
    print('controller wired')

# 2) 站点适配器：把 isRegistered<PlayerController> 代码块换成 CurrentLiveRoom.value
HOLDER = 'package:pure_live/domains/live/domain/current_live_room.dart'
for site in sorted(pathlib.Path('lib/domains/live/data/platforms').rglob('*_site.dart')):
    text = read(site)
    if 'PlayerController' not in text:
        continue
    lines = text.split('\n')
    out = []
    i = 0
    hits = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith('if (!Get.isRegistered<PlayerController>())'):
            # 提前返回式（kuaishou）：整段替换为只读入口
            indent = line[: len(line) - len(line.lstrip())]
            out.append(indent + 'final current = CurrentLiveRoom.value;')
            i += 1
            # 跳过原来的下一行 find 调用，保留后续逻辑
            if i < len(lines) and 'Get.find<PlayerController>' in lines[i]:
                i += 1
            hits += 1
            continue
        if stripped == 'if (Get.isRegistered<PlayerController>()) {':
            # 找到与之配对的右花括号，保留块内除声明外的语句，整体减一层缩进
            depth = 0
            j = i
            while j < len(lines):
                depth += lines[j].count('{') - lines[j].count('}')
                if depth == 0:
                    break
                j += 1
            indent = line[: len(line) - len(line.lstrip())]
            body = []
            for k in range(i + 1, j):
                inner = lines[k]
                if 'Get.find<PlayerController>()' in inner or 'Get.isRegistered<PlayerController>' in inner:
                    continue
                ded = inner[len(indent) + 2:] if inner.startswith(indent + '  ') else inner.lstrip()
                body.append(indent + ded)
            # 块内第一处需要 currentRoom：补一行只读取值
            for n, b in enumerate(body):
                if '.currentRoom' in b:
                    body[n] = indent + 'final currentRoom = CurrentLiveRoom.value;'
                    break
            out.extend(body)
            i = j + 1
            hits += 1
            continue
        out.append(line)
        i += 1
    if hits:
        text = '\n'.join(out)
        text = text.replace("import '%s';\n" % CAND, '').replace("import '%s';\r\n" % CAND, '')
        if 'CurrentLiveRoom' in text:
            text = add_import(text, HOLDER)
        write(site, text)
        print('site rewritten:', site.as_posix(), hits)
