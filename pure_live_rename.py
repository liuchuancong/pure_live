import json
import re

with open(r"D:\flutter\pure_live\assets\translations\zh.json", "r", encoding="utf-8") as f:
    data = json.load(f)

def fix_value(v):
    if isinstance(v, str):
        # {{xxx}} -> {xxx}
        return re.sub(r"\{\{(.*?)\}\}", r"{\1}", v)
    return v

# 修复 value
data = {k: fix_value(v) for k, v in data.items()}

# key排序
sorted_data = dict(sorted(data.items(), key=lambda x: x[0]))

with open("output.json", "w", encoding="utf-8") as f:
    json.dump(sorted_data, f, ensure_ascii=False, indent=2)