# Packs the bundled danmaku emoticons into one sprite sheet.
#
# The renderer's atlas mode (flame_barrage EmojiSourceType.atlas) supports a
# single global sheet: every emoticon becomes a rect in that sheet, and one
# image decode serves the whole catalogue. Five platforms' per-file images
# (1350 files, ~13.7 MB) become one PNG plus one JSON manifest, and the
# per-file directories stay out of the shipped bundle afterwards.
#
# Input:  assets/emo/json/<platform>.json   (the platforms' own lists)
#         assets/emo/images/<platform>/*    (the bundled copies)
# Output: assets/emo/atlas/atlas.json       ({"image","size","rects"})
#         assets/emo/atlas/atlas.png        (the packed sheet)
#
# The manifest is keyed by the emoticons' message text ("[微笑]"), because
# the renderer looks sprites up by the key the regex matched. Key parsing
# mirrors live_sites' DanmakuEmoji.fromPlatform per-platform shapes — keep
# the two in sync when a platform's list format changes.
#
# Run from packages/live_sites:  python tool/pack_emoji_atlas.py
# Requires Pillow. Sources stay in the repo as the tool's input; they are
# no longer declared in pubspec, so they do not ship.

import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
JSON_DIR = os.path.join(ROOT, "assets", "emo", "json")
IMAGES_DIR = os.path.join(ROOT, "assets", "emo", "images")
OUT_DIR = os.path.join(ROOT, "assets", "emo", "atlas")

SHEET_SIZE = 2048
PAD = 2  # px between cells, so edges never bleed

# Emoticons render at ~24 px tall; twice that keeps them sharp while the
# sheet stays small. Wider banners (douyu's long text faces) get a width
# cap as well; nothing is ever upscaled.
MAX_HEIGHT = 48
MAX_WIDTH = 96

# Cross-platform text collisions: the first platform in this order to
# claim a text owns it.
PLATFORMS = ["bilibili", "douyin", "douyu", "huya", "kuaishou"]


def entries_of(platform, raw):
    """Mirrors DanmakuEmoji.fromPlatform: (text keys, image file) per entry."""
    out = []
    if isinstance(raw, list):
        items = [("", item) for item in raw if isinstance(item, dict)]
    elif isinstance(raw, dict):
        items = [(key, value) for key, value in raw.items() if isinstance(value, dict)]
    else:
        return out

    def text(value):
        return value if isinstance(value, str) else ""

    for fallback_key, item in items:
        keys = []
        if platform == "bilibili":
            emoji = text(item.get("emoji"))
            key = emoji or fallback_key
        elif platform == "douyin":
            key = text(item.get("display_name"))
        elif platform == "kuaishou":
            key = fallback_key
        elif platform == "douyu":
            key = fallback_key if fallback_key.startswith("[") and fallback_key.endswith("]") else f"[{fallback_key}]"
        elif platform == "huya":
            key = text(item.get("sName"))
        else:
            continue
        if not key:
            continue
        keys.append(key)
        if platform == "huya":
            escape = text(item.get("sEscape"))
            if escape:
                keys.append(escape)
        local_file = text(item.get("local_file"))
        if local_file:
            out.append((keys, local_file))
    return out


def main():
    claimed = {}  # text -> (platform, file); first platform wins
    cells = {}  # path -> Image; keyed by full path, platforms can share names
    cell_keys = {}  # path -> [texts]

    for platform in PLATFORMS:
        with open(os.path.join(JSON_DIR, f"{platform}.json"), encoding="utf-8") as handle:
            raw = json.load(handle)
        for keys, local_file in entries_of(platform, raw):
            fresh = [key for key in keys if key not in claimed]
            if not fresh:
                continue
            path = os.path.join(IMAGES_DIR, platform, local_file)
            if not os.path.isfile(path):
                continue
            if path not in cells:
                cells[path] = Image.open(path)
                cell_keys[path] = []
            cell_keys[path].extend(fresh)
            for key in fresh:
                claimed[key] = (platform, path)

    # Decode now, scale to the caps, and order tallest first so the shelf
    # packing stays dense.
    packed = []
    for path, image in cells.items():
        image = image.convert("RGBA")
        width, height = image.size
        scale = min(1.0, MAX_HEIGHT / height if height else 1.0, MAX_WIDTH / width if width else 1.0)
        if scale < 1.0:
            image = image.resize((max(1, round(width * scale)), max(1, round(height * scale))), Image.LANCZOS)
        packed.append((path, image))
    packed.sort(key=lambda entry: (-entry[1].height, -entry[1].width))

    shelf_x = PAD
    shelf_y = PAD
    shelf_height = 0
    rects = {}
    for path, image in packed:
        width, height = image.size
        if shelf_x + width + PAD > SHEET_SIZE:
            shelf_x = PAD
            shelf_y += shelf_height + PAD
            shelf_height = 0
        if shelf_y + height + PAD > SHEET_SIZE:
            sys.exit(f"the sheet overflowed at {path}: raise the size or lower the caps")
        rects[path] = (shelf_x, shelf_y, width, height)
        shelf_x += width + PAD
        shelf_height = max(shelf_height, height)

    sheet = Image.new("RGBA", (SHEET_SIZE, SHEET_SIZE), (0, 0, 0, 0))
    for path, image in packed:
        x, y, _, _ = rects[path]
        sheet.paste(image, (x, y))

    os.makedirs(OUT_DIR, exist_ok=True)
    sheet.save(os.path.join(OUT_DIR, "atlas.png"), optimize=True)

    manifest = {
        "image": "atlas.png",
        "size": [SHEET_SIZE, SHEET_SIZE],
        "rects": {},
    }
    # The manifest's rects are keyed by the message text, the renderer's
    # sprite lookup key; one image's texts all point at its cell.
    for path, keys in cell_keys.items():
        x, y, width, height = rects[path]
        for key in keys:
            manifest["rects"][key] = [x, y, width, height]
    with open(os.path.join(OUT_DIR, "atlas.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, separators=(",", ":"))

    used = sum((w + PAD) * (h + PAD) for _, _, w, h in rects.values())
    print(f"emoticons packed: {len(packed)} images, {len(manifest['rects'])} text keys")
    print(f"sheet: {SHEET_SIZE}x{SHEET_SIZE}, fill {used / (SHEET_SIZE * SHEET_SIZE):.0%}")
    print(f"out: {os.path.relpath(OUT_DIR, ROOT)}")


if __name__ == "__main__":
    main()
