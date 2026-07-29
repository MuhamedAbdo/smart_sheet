import os
import glob
import re

files = glob.glob('lib/**/*.dart', recursive=True)
files.extend(glob.glob('test/**/*.dart', recursive=True))

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    
    # 1. Table name
    new_content = re.sub(r'(?<!die_cutting_)production_reports', 'flexo_production_reports', new_content)
    
    # 2. Box name
    new_content = new_content.replace('inkReports', 'flexo_production_reports_box')
    
    # 3. Model class
    new_content = re.sub(r'(?<!Flexo)(?<!DieCutting)ProductionReport', 'FlexoProductionReport', new_content)
    
    # 4. Import path
    new_content = re.sub(r'(?<!flexo_)(?<!die_cutting_)production_report\.dart', 'flexo_production_report.dart', new_content)
    
    if new_content != content:
        with open(file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file}")
