# Skills Repo Design

**Date:** 2026-03-20
**Repo:** `juice` — personal Claude Code skills manager

## Goal

A GitHub repo that stores personal Claude Code skills, version-controlled and bootstrappable on a new machine in one command. Skills are symlinked into `~/.claude/skills/` so edits in the repo reflect immediately without reinstalling.

## Repo Structure

```
juice/
├── README.md              ← skill index table (name, purpose, trigger)
├── install.sh             ← Mac/Linux: symlinks each skill folder into ~/.claude/skills/
├── install.ps1            ← Windows: same, using PowerShell symlinks
└── <skill-name>/
    └── SKILL.md           ← one folder per skill, flat layout
```

- One folder per skill, flat — no nesting beyond `<skill-name>/SKILL.md`
- Dotfiles and non-directories are skipped by install scripts
- No `metadata.json` — README is the index

## Install Scripts

### `install.sh` (Mac/Linux)
- Resolves repo root relative to script location
- Creates `~/.claude/skills/` if missing
- Loops over top-level directories, skips dotfiles, non-directories, and reserved folders (`docs`)
- Creates symlink: `~/.claude/skills/<name>` → `<repo>/<name>/` (link is `~/.claude/skills/<name>`, target is `<repo>/<name>/`)
- Warns (does not overwrite) if symlink already exists
- Idempotent — safe to re-run when new skills are added

### `install.ps1` (Windows)
- Same logic using `New-Item -ItemType SymbolicLink`
- Skips dotfiles, non-directories, and reserved folders (`docs`)
- Skips existing symlinks with a warning
- Requires Windows developer mode (no admin elevation needed)
- Run as: `powershell -ExecutionPolicy Bypass -File install.ps1` (or set `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` once)
- Idempotent

Both scripts print a summary of linked/skipped skills.

## README

- One-liner description
- Bootstrap instructions: `git clone ... && bash install.sh` (or `install.ps1`)
- Skill index table: `| Skill | Purpose | Triggers when... |`
- "Adding skills" section: copy folder into repo root, re-run install script

## Workflow

**New machine bootstrap:**
```
git clone git@github.com:you/juice.git
cd juice
bash install.sh        # Mac
./install.ps1          # Windows
```

**Adding a skill (from outside the repo — e.g. a skill not yet symlinked from juice):**
```
cp -r ~/.claude/skills/my-skill ./my-skill
git add my-skill && git commit -m "add my-skill"
```
Then re-run the install script to create the symlink. If the skill is already in the repo, no copy is needed — just re-run the install script.

## Out of Scope

- Migration script (user copies existing skills manually)
- `add-skill.sh` helper
- GitHub Pages / marketplace
- Git submodules or versioning beyond git tags
