import subprocess
import os
import re

def run_analyze():
    # Run flutter analyze and get output, using shell=True for Windows compatibility
    res = subprocess.run(["flutter", "analyze"], cwd="d:/Projek/otter_app", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout

def fix_const_errors():
    for attempt in range(25):
        print(f"--- Running flutter analyze (attempt {attempt + 1}) ---")
        output = run_analyze()
        
        # Look for constant creation errors:
        # e.g., "error - Arguments of a constant creation must be constant expressions - lib\widgets\navbar.dart:255:44 - const_with_non_constant_argument"
        errors = re.findall(r"error\s+-\s+([^-]+)\s+-\s+(\S+):(\d+):\d+", output)
        
        if not errors:
            print("No constant errors found!")
            break
            
        print(f"Found {len(errors)} errors. Inspecting...")
        
        modified = False
        for msg, file_rel_path, line_str in errors:
            msg = msg.strip()
            if "constant" not in msg.lower():
                continue
                
            file_path = os.path.join("d:/Projek/otter_app", file_rel_path.strip())
            line_no = int(line_str)
            
            if not os.path.exists(file_path):
                continue
                
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
                
            target_line_idx = line_no - 1
            fixed_this_error = False
            
            # Search upwards up to 15 lines for the 'const' keyword
            for check_idx in range(target_line_idx, max(-1, target_line_idx - 15), -1):
                line_content = lines[check_idx]
                if "const " in line_content:
                    new_line = re.sub(r'\bconst\s+', '', line_content)
                    if new_line != line_content:
                        lines[check_idx] = new_line
                        print(f"Removed const from {file_rel_path}:{check_idx + 1}")
                        fixed_this_error = True
                        modified = True
                        break
            
            if fixed_this_error:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.writelines(lines)
        
        if not modified:
            print("Could not find const keyword to remove for the remaining errors.")
            break

if __name__ == "__main__":
    fix_const_errors()
