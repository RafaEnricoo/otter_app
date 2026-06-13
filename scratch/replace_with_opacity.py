import os
import re

def replace_with_opacity_in_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace .withOpacity(...) with .withValues(alpha: ...)
    # Using regex to capture whatever is inside the parentheses, handling nested parens if any,
    # but since they are usually simple numeric values or variable expressions, a non-greedy wildcard works.
    # We can use a regex that matches .withOpacity( and then balance parentheses if needed, 
    # but let's do a robust replacement.
    
    pattern = r'\.withOpacity\(([^)]+)\)'
    new_content = re.sub(pattern, r'.withValues(alpha: \1)', content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

def run_replacement():
    lib_dir = "d:/Projek/otter_app/lib"
    modified_count = 0
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                if replace_with_opacity_in_file(file_path):
                    print(f"Updated: {file_path}")
                    modified_count += 1
    print(f"Total modified files: {modified_count}")

if __name__ == "__main__":
    run_replacement()
