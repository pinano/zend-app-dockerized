#!/usr/bin/env python3
import os
import sys
import shutil
import re

def main():
    print("🚀 Zend Legacy Entrypoint Tool")
    print("──────────────────────────────")

    # Paths definitions
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    docs_dir = os.path.join(base_dir, 'docs')
    docroot_dir = os.path.join(base_dir, 'docroot')
    weblibs_dir = os.path.join(docroot_dir, 'weblibs')
    
    index_sample = os.path.join(docs_dir, 'index.php.sample')
    target_public = os.path.join(docroot_dir, 'public')
    target_index = os.path.join(target_public, 'index.php')

    # Ensure docroot directory exists
    if not os.path.exists(docroot_dir):
        print(f"📁 Creating docroot directory at: {docroot_dir}")
        os.makedirs(docroot_dir, exist_ok=True)

    # Ensure weblibs directory exists
    if not os.path.exists(weblibs_dir):
        print(f"📁 Creating weblibs directory at: {weblibs_dir}")
        os.makedirs(weblibs_dir, exist_ok=True)
        print("💡 Place your project libraries (e.g. Zend Framework, FPDF) in this folder.")

    # 1. SCAN WEBLIBS
    detected_paths = []
    print(f"🔍 Scanning for libraries in: {weblibs_dir} ...")
    if os.path.exists(weblibs_dir):
        # List subdirectories
        for item in sorted(os.listdir(weblibs_dir)):
            item_path = os.path.join(weblibs_dir, item)
            if os.path.isdir(item_path):
                # Check for standard subfolders like 'Classes' (common for PHPExcel)
                classes_path = os.path.join(item_path, 'Classes')
                if os.path.isdir(classes_path):
                    container_path = f"/var/www/html/weblibs/{item}/Classes"
                else:
                    container_path = f"/var/www/html/weblibs/{item}"
                detected_paths.append(container_path)
                print(f"  ➕ Found library: {item} -> mapped to {container_path}")

    # 2. GENERATE INDEX.PHP
    if not os.path.exists(index_sample):
        print(f"❌ ERROR: Sample index.php not found at {index_sample}", file=sys.stderr)
        sys.exit(1)

    print("📄 Processing index.php...")
    with open(index_sample, 'r') as f:
        index_content = f.read()

    if detected_paths:
        # Build the paths block
        paths_lines = []
        for path in detected_paths:
            paths_lines.append(f"    '{path}',")
        paths_str = "\n".join(paths_lines)
        
        # Replace the paths block in index.php
        # Match from $paths = [ to get_include_path()
        pattern = r'(\$paths\s*=\s*\[)([\s\S]*?)(get_include_path\(\))'
        if re.search(pattern, index_content):
            # Keep the opening bracket, insert detected paths, keep get_include_path()
            replacement = r'\1\n' + paths_str + r'\n    \3'
            new_index_content = re.sub(pattern, replacement, index_content)
            print("  ✅ Updated include paths with scanned weblibs.")
        else:
            new_index_content = index_content
            print("  ⚠️ Could not auto-replace paths array. Writing original template.")
    else:
        new_index_content = index_content
        print("  ⚠️ No custom libraries found in weblibs. Using default template values.")

    # Write target index.php
    os.makedirs(target_public, exist_ok=True)
    if os.path.exists(target_index):
        backup_path = target_index + '.bak'
        print(f"  ⚠️ File already exists. Backing up existing index.php to {os.path.basename(backup_path)}")
        shutil.copy2(target_index, backup_path)
        
    with open(target_index, 'w') as f:
        f.write(new_index_content)
    print(f"  🎉 Created/Updated: {target_index}")
    print("──────────────────────────────")
    print("✅ Setup complete! index.php initialized in docroot/public/.")

if __name__ == '__main__':
    main()
