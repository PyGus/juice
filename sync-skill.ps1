param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName,

    [string]$From = ""
)

$ErrorActionPreference = 'Stop'
$RepoDir = $PSScriptRoot

if ($From) {
    $Source = Join-Path $From ".claude\skills\$SkillName"
} else {
    $Source = Join-Path $HOME ".claude\skills\$SkillName"
}

$Dest = Join-Path $RepoDir $SkillName

# Guard: already in repo (also catches dangling symlinks, where Test-Path returns $false)
$destItem = Get-Item $Dest -ErrorAction SilentlyContinue
if ((Test-Path $Dest) -or ($null -ne $destItem)) {
    Write-Host "Error: '$SkillName' already exists in the repo at $Dest"
    Write-Host "If you want to update it, edit the file directly (it may already be symlinked)."
    exit 1
}

# Guard: source must exist
if (-not (Test-Path $Source)) {
    Write-Host "Error: skill not found at $Source"
    exit 1
}

# Guard: source must not already be a symlink
$item = Get-Item $Source -ErrorAction SilentlyContinue
if ($item.LinkType -eq "SymbolicLink") {
    Write-Host "Error: $Source is already a symlink -- this skill is likely already in the repo."
    exit 1
}

# Copy into repo
Copy-Item -Recurse -Path $Source -Destination $Dest
Write-Host "Copied: $Source -> $Dest"

# Remove original
Remove-Item -Recurse -Force $Source
Write-Host "Removed original: $Source"

# Re-run install using the call operator (same runtime as caller, works under both powershell.exe and pwsh)
& (Join-Path $RepoDir "install.ps1")
