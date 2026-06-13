import os

def refactor_colors():
    lib_dir = "d:/Projek/otter_app/lib"
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith(".dart"):
                continue
            filepath = os.path.join(root, file)
            # Skip core files and settings service to avoid circular dependency or changing palette definitions
            if "constants.dart" in file or "system_settings_service.dart" in file or "settings_screen.dart" in file:
                continue
                
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            
            new_content = content
            # Replace const Color(0xFF00F4FE) with Color(AppColors.secondaryContainer)
            new_content = new_content.replace("const Color(0xFF00F4FE)", "Color(AppColors.secondaryContainer)")
            # Replace Color(0xFF00F4FE) with Color(AppColors.secondaryContainer)
            new_content = new_content.replace("Color(0xFF00F4FE)", "Color(AppColors.secondaryContainer)")
            
            if new_content != content:
                print(f"Refactoring colors in {file}...")
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)

if __name__ == "__main__":
    refactor_colors()
