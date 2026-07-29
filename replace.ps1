$files = Get-ChildItem -Path "lib", "test" -Recurse -Filter "*.dart"
foreach ($file in $files) {
    # Skip generated files
    if ($file.Name -match "\.g\.dart") { continue }
    
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    if ($null -eq $content) { continue }
    
    # 1. Table name
    $newContent = [regex]::Replace($content, '(?<!die_cutting_)production_reports', 'flexo_production_reports')
    
    # 2. Box name
    $newContent = [regex]::Replace($newContent, 'inkReports', 'flexo_production_reports_box')
    
    # 3. Model class
    $newContent = [regex]::Replace($newContent, '(?<!Flexo)(?<!DieCutting)ProductionReport', 'FlexoProductionReport')
    
    # 4. Import path
    $newContent = [regex]::Replace($newContent, '(?<!flexo_)(?<!die_cutting_)production_report\.dart', 'flexo_production_report.dart')
    
    if ($newContent -cne $content) {
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "Updated $($file.FullName)"
    }
}
