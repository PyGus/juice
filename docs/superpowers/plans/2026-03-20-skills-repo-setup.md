# Skills Repo Setup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up the `juice` repo as a personal Claude Code skills manager with install and sync scripts for Windows and Mac.

**Architecture:** Flat repo structure — one folder per skill. Install scripts symlink each skill folder into `~/.claude/skills/`. Sync scripts import newly-created skills from user or project scope into the repo, remove the original, and re-run install to put the symlink back.

**Tech Stack:** Bash (Mac/Linux), PowerShell (Windows). No dependencies beyond standard shell tools.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `install.sh` | Create | Mac/Linux: symlink all skill folders into `~/.claude/skills/` |
| `install.ps1` | Create | Windows: same using PowerShell symlinks |
| `sync-skill.sh` | Create | Mac/Linux: import a new skill from user/project scope into repo |
| `sync-skill.ps1` | Create | Windows: same |
| `README.md` | Modify | Replace placeholder with full docs + skill index table |

Reserved top-level folders that scripts must skip: `docs`

---

## Task 1: `install.sh`

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Write `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
RESERVED=("docs")

mkdir -p "$SKILLS_DIR"

linked=0
skipped=0

for skill_dir in "$REPO_DIR"/*/; do
  skill_name=$(basename "$skill_dir")

  # Skip dotfiles
  [[ "$skill_name" == .* ]] && continue

  # Skip non-directories
  [[ ! -d "$skill_dir" ]] && continue

  # Skip reserved folders
  skip=false
  for reserved in "${RESERVED[@]}"; do
    [[ "$skill_name" == "$reserved" ]] && skip=true && break
  done
  if $skip; then
    echo "Skipping reserved: $skill_name"
    ((skipped++))
    continue
  fi

  target="$SKILLS_DIR/$skill_name"

  if [[ -e "$target" || -L "$target" ]]; then
    echo "Skipping (already exists): $skill_name"
    ((skipped++))
  else
    ln -s "${skill_dir%/}" "$target"
    echo "Linked: $skill_name"
    ((linked++))
  fi
done

echo ""
echo "Done. Linked: $linked, Skipped: $skipped"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Verify — no skill folders present**

Run: `bash install.sh`

Expected output:
```
Done. Linked: 0, Skipped: 1
```
(`docs` is the only top-level directory and should be skipped as reserved.)

- [ ] **Step 4: Verify — with a dummy skill**

```bash
mkdir -p /tmp/test-skill && echo "# test" > /tmp/test-skill/SKILL.md
cp -r /tmp/test-skill ./test-skill
bash install.sh
ls -la ~/.claude/skills/test-skill
```

Expected: symlink pointing back into the repo. Then clean up:

```bash
rm -rf ./test-skill
rm -f ~/.claude/skills/test-skill
```

- [ ] **Step 5: Verify idempotency — run twice, no errors**

```bash
bash install.sh && bash install.sh
```

Expected: second run prints `Skipping (already exists): ...` for any linked skills, exits cleanly.

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh for Mac/Linux"
```

---

## Task 2: `install.ps1`

**Files:**
- Create: `install.ps1`

> **Windows only.** Requires developer mode enabled. Run with `powershell -ExecutionPolicy Bypass -File install.ps1`.

- [ ] **Step 1: Write `install.ps1`**

```powershell
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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
```

- [ ] **Step 2: Verify — no skill folders present**

Run: `powershell -ExecutionPolicy Bypass -File install.ps1`

Expected output:
```
Skipping reserved: docs

Done. Linked: 0, Skipped: 1
```

- [ ] **Step 3: Verify — with a dummy skill**

```powershell
New-Item -ItemType Directory -Path .\test-skill | Out-Null
"# test" | Out-File .\test-skill\SKILL.md
powershell -ExecutionPolicy Bypass -File install.ps1
Get-Item "$HOME\.claude\skills\test-skill" | Select-Object LinkType, Target
```

Expected: `LinkType = SymbolicLink`, Target points into repo. Then clean up:

```powershell
Remove-Item -Recurse .\test-skill
Remove-Item "$HOME\.claude\skills\test-skill"
```

- [ ] **Step 4: Verify idempotency**

Run `install.ps1` twice. Second run must print `Skipping (already exists)` for any linked skills and exit cleanly.

- [ ] **Step 5: Commit**

```bash
git add install.ps1
git commit -m "feat: add install.ps1 for Windows"
```

---

## Task 3: `sync-skill.sh`

**Files:**
- Create: `sync-skill.sh`

- [ ] **Step 1: Write `sync-skill.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: $0 <skill-name> [--from <project-path>]"
  echo ""
  echo "  <skill-name>          Name of the skill to import"
  echo "  --from <path>         Import from <path>/.claude/skills/ instead of ~/.claude/skills/"
  exit 1
}

[[ $# -lt 1 ]] && usage

SKILL_NAME="$1"
FROM_PATH=""
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM_PATH="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -n "$FROM_PATH" ]]; then
  SOURCE="$FROM_PATH/.claude/skills/$SKILL_NAME"
else
  SOURCE="$HOME/.claude/skills/$SKILL_NAME"
fi

DEST="$REPO_DIR/$SKILL_NAME"

# Guard: already in repo
if [[ -d "$DEST" ]]; then
  echo "Error: '$SKILL_NAME' already exists in the repo at $DEST"
  echo "If you want to update it, edit the file directly (it may already be symlinked)."
  exit 1
fi

# Guard: source must exist and not be a symlink (i.e. already managed by repo)
if [[ ! -d "$SOURCE" ]]; then
  echo "Error: skill not found at $SOURCE"
  exit 1
fi

if [[ -L "$SOURCE" ]]; then
  echo "Error: $SOURCE is already a symlink — this skill is likely already in the repo."
  exit 1
fi

# Copy into repo
cp -r "$SOURCE" "$DEST"
echo "Copied: $SOURCE → $DEST"

# Remove original
rm -rf "$SOURCE"
echo "Removed original: $SOURCE"

# Re-run install to symlink back
bash "$REPO_DIR/install.sh"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x sync-skill.sh
```

- [ ] **Step 3: Verify — happy path (user scope)**

```bash
# Create a fake skill in user scope
mkdir -p ~/.claude/skills/fake-skill
echo "# fake" > ~/.claude/skills/fake-skill/SKILL.md

bash sync-skill.sh fake-skill
```

Expected:
- `fake-skill/` appears in repo root
- `~/.claude/skills/fake-skill` is now a symlink pointing into repo
- Install summary printed

Clean up:
```bash
rm -rf ./fake-skill
rm -f ~/.claude/skills/fake-skill
```

- [ ] **Step 4: Verify — project scope (`--from`)**

```bash
mkdir -p /tmp/myproject/.claude/skills/proj-skill
echo "# proj" > /tmp/myproject/.claude/skills/proj-skill/SKILL.md

bash sync-skill.sh proj-skill --from /tmp/myproject
```

Expected: same as above but source is `/tmp/myproject/.claude/skills/proj-skill`.

Clean up:
```bash
rm -rf ./proj-skill ~/.claude/skills/proj-skill /tmp/myproject
```

- [ ] **Step 5: Verify — errors on duplicate**

```bash
mkdir -p ./already-exists
bash sync-skill.sh already-exists 2>&1
```

Expected: `Error: 'already-exists' already exists in the repo at ...`

Clean up: `rm -rf ./already-exists`

- [ ] **Step 6: Verify — errors on missing source**

```bash
bash sync-skill.sh nonexistent-skill 2>&1
```

Expected: `Error: skill not found at ...`

- [ ] **Step 7: Commit**

```bash
git add sync-skill.sh
git commit -m "feat: add sync-skill.sh for Mac/Linux"
```

---

## Task 4: `sync-skill.ps1`

**Files:**
- Create: `sync-skill.ps1`

> **Windows only.**

- [ ] **Step 1: Write `sync-skill.ps1`**

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName,

    [string]$From = ""
)

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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
    Write-Host "Error: $Source is already a symlink — this skill is likely already in the repo."
    exit 1
}

# Copy into repo
Copy-Item -Recurse -Path $Source -Destination $Dest
Write-Host "Copied: $Source → $Dest"

# Remove original
Remove-Item -Recurse -Force $Source
Write-Host "Removed original: $Source"

# Re-run install using the call operator (same runtime as caller, works under both powershell.exe and pwsh)
& (Join-Path $RepoDir "install.ps1")
```

- [ ] **Step 2: Verify — happy path (user scope)**

```powershell
New-Item -ItemType Directory "$HOME\.claude\skills\fake-skill" | Out-Null
"# fake" | Out-File "$HOME\.claude\skills\fake-skill\SKILL.md"

powershell -ExecutionPolicy Bypass -File sync-skill.ps1 -SkillName fake-skill
```

Expected:
- `fake-skill\` appears in repo root
- `~\.claude\skills\fake-skill` is a symlink pointing into repo

Clean up:
```powershell
Remove-Item -Recurse .\fake-skill
Remove-Item "$HOME\.claude\skills\fake-skill"
```

- [ ] **Step 3: Verify — errors on duplicate and missing source**

```powershell
# Duplicate
New-Item -ItemType Directory .\already-exists | Out-Null
powershell -ExecutionPolicy Bypass -File sync-skill.ps1 -SkillName already-exists
# Expected: Error about already existing in repo
Remove-Item -Recurse .\already-exists

# Missing
powershell -ExecutionPolicy Bypass -File sync-skill.ps1 -SkillName nonexistent
# Expected: Error about skill not found
```

- [ ] **Step 4: Commit**

```bash
git add sync-skill.ps1
git commit -m "feat: add sync-skill.ps1 for Windows"
```

---

## Task 5: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README content**

Replace the entire file with:

```markdown
# juice

Personal Claude Code skills — version-controlled and bootstrappable in one command.

## Bootstrap

```bash
git clone git@github.com:<your-username>/juice.git
cd juice

# Mac/Linux
bash install.sh

# Windows (requires developer mode)
powershell -ExecutionPolicy Bypass -File install.ps1
```

Skills are symlinked into `~/.claude/skills/` so edits in the repo reflect immediately.

## Skills

| Skill | Purpose | Triggers when... |
|-------|---------|-----------------|
| _(add your skills here)_ | | |

## Adding Skills

**Via sync script** (after using the skill creator):
```bash
bash sync-skill.sh my-skill                        # from user scope (~/.claude/skills/)
bash sync-skill.sh my-skill --from /path/to/repo   # from project scope
powershell -ExecutionPolicy Bypass -File sync-skill.ps1 -SkillName my-skill  # Windows
```

**Manually:**
```bash
cp -r ~/.claude/skills/my-skill ./my-skill
bash install.sh
git add my-skill && git commit -m "add my-skill"
```

Then update the Skills table above.
```

- [ ] **Step 2: Verify the README renders correctly**

Open `README.md` and confirm:
- Skill table is present
- Code blocks are not broken
- Both platform bootstrap commands are shown

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README with bootstrap instructions and skill index"
```
