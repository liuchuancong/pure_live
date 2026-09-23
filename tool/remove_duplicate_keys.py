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
    remove_duplicate_keys(
        r"D:\flutter\pure_live\assets\translations\zh.json"
    )