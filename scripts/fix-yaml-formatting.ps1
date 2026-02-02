#!/usr/bin/env pwsh
# Fix Wave 1 ansible-lint violations: trailing spaces, EOF newlines, comma spacing

$ErrorActionPreference = "Stop"
$fixed = 0
$errors = 0

Write-Host "Fixing YAML formatting issues..." -ForegroundColor Cyan

# Get all YAML files excluding temp, .git, .cache
$yamlFiles = Get-ChildItem -Path . -Include *.yml,*.yaml -Recurse -File | 
    Where-Object { $_.FullName -notmatch '[\\/](\.git|temp|\.cache)[\\/]' }

foreach ($file in $yamlFiles) {
    try {
        $originalContent = Get-Content $file.FullName -Raw
        if (-not $originalContent) {
            Write-Host "  Skipped (empty): $($file.FullName)" -ForegroundColor Yellow
            continue
        }

        # Fix trailing spaces on each line
        $lines = $originalContent -split "`r?`n"
        $fixedLines = $lines | ForEach-Object { $_ -replace '\s+$', '' }
        
        # Join with LF and ensure single newline at EOF
        $newContent = ($fixedLines -join "`n").TrimEnd("`n") + "`n"
        
        # Only write if content changed
        if ($newContent -ne $originalContent) {
            [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  Fixed: $($file.Name)" -ForegroundColor Green
            $fixed++
        }
    }
    catch {
        Write-Host "  Error fixing $($file.Name): $_" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Files fixed: $fixed" -ForegroundColor Green
Write-Host "  Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })
Write-Host "  Total processed: $($yamlFiles.Count)" -ForegroundColor White
