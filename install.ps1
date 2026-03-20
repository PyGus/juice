$RepoDir = $PSScriptRoot
$SkillsDir = Join-Path $HOME ".claude\skills"
$Reserved = @("docs")

if (-not (Test-Path $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir | Out-Null
}

$linked = 0
$skipped = 0

Get-ChildItem -Path $RepoDir -Directory | ForEach-Object {
    $name = $_.Name

    # Skip dotfiles
    if ($name.StartsWith(".")) { return }

    # Skip reserved folders
    if ($Reserved -contains $name) {
        Write-Host "Skipping reserved: $name"
        $skipped++
        return
    }

    $target = Join-Path $SkillsDir $name

    # Check for existing path OR dangling symlink (Test-Path returns $false for dangling symlinks)
    $existing = Get-Item $target -ErrorAction SilentlyContinue
    if ((Test-Path $target) -or ($null -ne $existing)) {
        Write-Host "Skipping (already exists): $name"
        $skipped++
    } else {
        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName | Out-Null
        Write-Host "Linked: $name"
        $linked++
    }
}

Write-Host ""
Write-Host "Done. Linked: $linked, Skipped: $skipped"
