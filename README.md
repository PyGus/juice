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
rm -rf ~/.claude/skills/my-skill   # remove original so install.sh can symlink it back
bash install.sh
git add my-skill && git commit -m "add my-skill"
```

Then update the Skills table above.
