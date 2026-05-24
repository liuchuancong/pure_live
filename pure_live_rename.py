import os
import re

def strip_font_size_from_app_styles(content):
    # 💡 匹配所有 AppTextStyles.tXX.copyWith(...) 结构，支持跨多行
    pattern_copyWith = re.compile(
        r'(AppTextStyles\.t\d+\.copyWith\()(.*?)(\))', 
        re.DOTALL
    )
    
    def remove_font_size(match):
        prefix = match.group(1)   # AppTextStyles.tXX.copyWith(
        inner_body = match.group(2) # 括号内部的所有属性文本
        suffix = match.group(3)   # )
        
        # 💡 正则移除各种换行、带浮点数或逗号的 fontSize: 17, 属性
        cleaned_body = re.sub(
            r'fontSize:\s*\d+(?:\.0)?,?\s*', 
            '', 
            inner_body
        )
        
        # 修正因移除导致的尾部或开头多余逗号与空白
        cleaned_body = cleaned_body.strip()
        if cleaned_body.endswith(','):
            # 如果剔除后末尾有多余的逗号，安全抹除它
            cleaned_body = re.sub(r',\s*$', '', cleaned_body)
            
        # 如果内部属性全被删空了，直接退化为纯基础样式
        if not cleaned_body:
            return prefix.replace('.copyWith(', '')
            
        return f"{prefix}{cleaned_body}{suffix}"

    content = pattern_copyWith.sub(remove_font_size, content)
    return content

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    content = strip_font_size_from_app_styles(content)

    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f" Successfully cleaned fontSize from: {file_path}")

def run_refactor():
    lib_dir = os.path.join(os.getcwd(), 'lib')
    if not os.path.exists(lib_dir):
        print("Error: 'lib' directory not found. Run in project root.")
        return

    print("🚀 Cleaning redundant fontSizes inside AppTextStyles across all files...")
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))
    print("✨ Clean sweep complete!")

if __name__ == "__main__":
    run_refactor()
