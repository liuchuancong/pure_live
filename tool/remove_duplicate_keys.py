import json
from pathlib import Path


def remove_duplicate_keys(file_path):
    path = Path(file_path)

    def process_object(pairs):
        result = {}
        # 后面的 key 覆盖前面的 key
        for key, value in pairs:
            result[key] = value
        return result

    # 读取
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f, object_pairs_hook=process_object)

    # 直接覆盖原文件
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"处理完成：{path}")


if __name__ == "__main__":
    # 当前脚本所在目录（项目根目录）
    project_dir = Path(__file__).resolve().parent.parent

    translations_dir = project_dir / "assets" / "translations"

    remove_duplicate_keys(translations_dir / "zh.json")
    remove_duplicate_keys(translations_dir / "en.json")