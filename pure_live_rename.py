import os
import re

def refactor_text_styles(content):
    # 💡 支持清洗的所有目标字号映射表
    target_sizes = [11, 12, 13, 14, 15, 16, 18, 20]
    
    for size in target_sizes:
        # 正则表达式支持匹配 16 或 16.0
        size_pattern = f"{size}(?:\.0)?"
        
        # 模式 1：fontSize 排在第一位，且后续有多行属性
        pattern_first = re.compile(
            r'style:\s*(?:const\s*)?TextStyle\(\s*fontSize:\s*' + size_pattern + r',\s*(.*?)\)', 
            re.DOTALL
        )
        content = pattern_first.sub(f'style: AppTextStyles.t{size}.copyWith(\\1)', content)
        
        # 模式 2：fontSize 排在中间或最后，前后都有多行属性
        pattern_complex = re.compile(
            r'style:\s*(?:const\s*)?TextStyle\(\s*(.*?),\s*fontSize:\s*' + size_pattern + r',?\s*(.*?)\)', 
            re.DOTALL
        )
        
        def replace_complex(match, s=size):
            part1 = match.group(1).strip()
            part2 = match.group(2).strip()
            remaining = [p for p in [part1, part2] if p]
            if remaining:
                return f"style: AppTextStyles.t{s}.copyWith({', '.join(remaining)})"
            return f"style: AppTextStyles.t{s}"
            
        content = pattern_complex.sub(replace_complex, content)
        
        # 模式 3：最基础的单行干净组件 style: const TextStyle(fontSize: 16.0)
        pattern_pure = r'style:\s*const\s*TextStyle\(\s*fontSize:\s*' + size_pattern + r',?\s*\)'
        content = re.sub(pattern_pure, f'style: AppTextStyles.t{size}', content)

    return content

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    content = refactor_text_styles(content)

    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f" Successfully refactored: {file_path}")

def run_refactor():
    lib_dir = os.path.join(os.getcwd(), 'lib')
    if not os.path.exists(lib_dir):
        print("Error: 'lib' directory not found. Run in project root.")
        return

    print("🚀 Running ULTIMATE typography refactoring engine (All sizes, multi-line, floats)...")
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))
    print("✨ Global clean sweep complete!")

if __name__ == "__main__":
    run_refactor()
