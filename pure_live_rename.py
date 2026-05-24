import os
import re

def refactor_ternary_font_sizes(content):
    # 💡 匹配任何包含三元运算符字号的 TextStyle 结构（支持单行、多行、以及任意换行属性）
    # 能完美拿下：style: TextStyle(fontSize: dense ? 13 : 15, fontWeight: FontWeight.w500)
    # 以及：fontSize: dense ? 12 : 13 在中间或末尾的各种变体
    pattern_ternary = re.compile(
        r'(?:const\s+)?TextStyle\(\s*(.*?)\s*\)', 
        re.DOTALL
    )
    
    def replace_ternary(match):
        inner_content = match.group(1)
        
        # 检查是否包含三元运算符的 fontSize 配置
        # 匹配诸如: fontSize: dense ? 13 : 15 或 fontSize: dense ? 13.0 : 15.0
        fontSize_match = re.search(
            r'fontSize:\s*([\w\.]+)\s*\?\s*(\d+)(?:\.0)?\s*:\s*(\d+)(?:\.0)?', 
            inner_content
        )
        
        if fontSize_match:
            bool_var = fontSize_match.group(1)      # 例如: dense
            size_true = fontSize_match.group(2)     # 例如: 13
            size_false = fontSize_match.group(3)    # 例如: 15
            
            # 从原始属性中把整个 fontSize:... 表达式剔除，只保留剩余属性
            cleaned_inner = re.sub(
                r'fontSize:\s*[\w\.]+\s*\?\s*\d+(?:\.0)?\s*:\s*\d+(?:\.0)?,?\s*', 
                '', 
                inner_content
            ).strip()
            
            # 清理尾部多余的逗号
            if cleaned_inner.endswith(','):
                cleaned_inner = cleaned_inner[:-1].strip()
                
            # 拼装优雅的目标代码结构
            if cleaned_inner:
                return f"({bool_var} ? AppTextStyles.t{size_true} : AppTextStyles.t{size_false}).copyWith({cleaned_inner})"
            else:
                return f"({bool_var} ? AppTextStyles.t{size_true} : AppTextStyles.t{size_false})"
        
        return match.group(0) # 如果没有三元字号，保持原样原封不动

    # 针对代码中的 style: TextStyle(...) 这一整块执行正则替换转换
    content = re.sub(r'style:\s*(?:const\s+)?TextStyle\(\s*(.*?)\s*\)', lambda m: f"style: {replace_ternary(m)}", content, flags=re.DOTALL)
    return content

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    content = refactor_ternary_font_sizes(content)

    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f" Successfully refactored ternary text styles in: {file_path}")

def run_refactor():
    lib_dir = os.path.join(os.getcwd(), 'lib')
    if not os.path.exists(lib_dir):
        print("Error: 'lib' directory not found. Please run this script in your Flutter project root.")
        return

    print("🚀 Running INTELLIGENT TERNARY typography engine (Cleaning dense ? X : Y)...")
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))
    print("✨ Ternary typography migration complete!")

if __name__ == "__main__":
    run_refactor()
