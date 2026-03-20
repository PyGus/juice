---
name: opencode-glm-plan
description: Delegates coding IMPLEMENTATION tasks to OpenCode/GLM-5 — GLM writes the code and files, Claude architects and reviews. Trigger when the user wants GLM/OpenCode to execute actual coding work rather than having Claude do it. Trigger on: "delegate to GLM", "have opencode write/implement X", "let GLM do this", "ask GLM to code X", "GLM should handle this", "use opencode to build/write X", "offload this to opencode/GLM", or any request where GLM/OpenCode should be the one producing code. Do NOT trigger for: read-only analysis, security review, architecture review, code explanation, or when the user explicitly wants Claude to write the code itself.
---

## Roles

**Claude** — architect, planner, context provider, reviewer
**GLM-5 via OpenCode** — code executor, implements bounded tasks Claude defines

Communication between them happens through a **shared scratchpad file** in the project.

### Model selection

| Model | When to use |
|-------|-------------|
| `zai-coding-plan/glm-5` | Default — strongest reasoning, best for complex or ambiguous tasks |
| `zai-coding-plan/glm-5-turbo` | Faster variant of GLM-5, good for straightforward tasks |
| `zai-coding-plan/glm-4.7` | Fallback — use when GLM-5 quota is exhausted, off-peak hours don't matter, or the task is simple enough that GLM-4.7 will handle it fine |

GLM-5 uses 2–3× quota per token vs GLM-4.7's 1×. For routine tasks (adding a function, small refactors), GLM-4.7 is usually sufficient. Swap `--model zai-coding-plan/glm-4.7` anywhere you see `zai-coding-plan/glm-5`.

---

## Shared Scratchpad Protocol

The scratchpad is a markdown file both sides read and write. It lives in `.glm/` in the current working directory.

**Claude writes**: task spec, context, constraints, answers to GLM's questions
**GLM writes**: questions (if blocked), completed output, status updates

### Scratchpad structure

```markdown
# GLM Delegation Session: <short task name>
Session: <timestamp>

## Task
<clear, bounded description of exactly what to implement>

## Context
Working directory: <pwd>
Recent commits:
<git log --oneline -5>

Relevant files:
<ls or specific file contents>

## Constraints
- Do NOT modify files outside the scope defined below
- Follow existing code style and patterns
- Output files: <list target file paths>
- <any other constraints>

## Questions for Claude
<!-- GLM: if you need clarification, write questions here, set Status → questions-pending, then STOP -->

## Answers from Claude
<!-- Claude adds answers here before re-running -->

## Output / Results
<!-- GLM: write a summary of what was implemented and which files were changed -->

## Status
pending
```

---

## Step-by-step procedure

### 1. Pre-flight

**a) Check OpenCode auth:**
```bash
opencode auth list   # "Z.AI Coding Plan" must be listed
```
If Z.AI isn't listed: stop and tell the user to run `opencode auth login`.

**b) Check global Bash permission:**

Read `~/.claude/settings.json`. Check whether `"Bash(opencode:*)"` is present in `permissions.allow`. If missing, offer to add it — this covers both the main session and the `claude -p` background subprocess approach used in step 3.

### 2. Create the scratchpad

Derive a short slug from the task (kebab-case, 2–4 words).

```bash
mkdir -p .glm
TASK_SLUG="<short-task-slug>"
SESSION_FILE=".glm/${TASK_SLUG}-$(date +%s).md"

cat > "$SESSION_FILE" << EOF
# GLM Delegation Session: <short-task-name>
Session: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Task
<DESCRIBE THE TASK CLEARLY — what to build, what files to create/modify>

## Context
Working directory: $(pwd)

Recent commits:
$(git log --oneline -5 2>/dev/null || echo "not a git repo")

Git status:
$(git status --short 2>/dev/null || echo "clean")

Directory listing:
$(ls -la)

<PASTE ANY RELEVANT FILE CONTENTS HERE>

## Constraints
- Do NOT modify files outside the scope defined above
- Follow existing patterns in the codebase
- Output files: <target file paths>
- <add any other constraints>

## Questions for Claude
<!-- GLM: if you need clarification before you can proceed, write your questions here,
     set Status to "questions-pending", and STOP. Do not guess. -->

## Answers from Claude
<!-- Claude will add answers here when questions are present -->

## Output / Results
<!-- GLM: when complete, write a summary of what was implemented and which files were changed -->

## Status
pending
EOF
```

Include relevant file contents in the Context section — the more GLM knows, the fewer questions it asks.

### 3. Run OpenCode

**Preferred: background via `claude -p`**

Use `claude -p` as a background Bash process — this passes explicit `--allowedTools` so the subprocess can run `opencode` without any permission prompts, and the `&` keeps the main session free:

```bash
LOG_FILE="/tmp/glm-$(date +%s).log"
claude -p "You are a GLM delegation runner.

Run this exact bash command:
opencode run --model zai-coding-plan/glm-5 \"$(cat $SESSION_FILE | sed 's/\"/\\\"/g')\"

After it exits, read $SESSION_FILE and report:
- If Status = complete: paste ## Output / Results
- If Status = questions-pending: paste ## Questions for Claude verbatim
- Otherwise: paste any error output" \
  --allowedTools "Bash(opencode:*)" \
  --output-format json \
  > "$LOG_FILE" 2>&1 &
GLM_PID=$!
echo "GLM running (PID $GLM_PID) → $LOG_FILE"
```

Poll for completion:
```bash
# Check if done
kill -0 $GLM_PID 2>/dev/null && echo "still running..." || cat "$LOG_FILE"
```

Or wait for it:
```bash
wait $GLM_PID && cat "$LOG_FILE"
```

**Fallback: inline in main session** (if the above has issues):
```bash
opencode run --model zai-coding-plan/glm-5 "$(cat $SESSION_FILE)"
```
Use `timeout: 180000` on the Bash tool. GLM typically finishes in 30–120 seconds.

### 4. Handle the result

**Status = `complete`** → go to step 5.

**Status = `questions-pending`** → GLM needs clarification. Answer it yourself if the answer is obvious from context; otherwise ask the user. Then append to the scratchpad:

```bash
cat >> "$SESSION_FILE" << EOF

<!-- Claude answered on $(date -u +"%Y-%m-%dT%H:%M:%SZ") -->
<ANSWERS>
EOF
```

Re-run step 3 with the updated scratchpad.

### 5. Review and surface results

Read `## Output / Results` and the changed files. Tell the user:
- What GLM built
- Which files changed
- Any review concerns

Keep the session file as an audit trail, or clean up with `rm "$SESSION_FILE"`.

---

## Context injection tips

The more context you inject in step 2, the better the output and fewer questions GLM asks. Good things to include:

- The specific file(s) to modify: `cat src/foo.py`
- Interfaces or types GLM needs to implement against
- An example of a similar function that already exists in the codebase
- The test file GLM should make pass

---

## Checklist before delegating

- [ ] `opencode auth list` shows Z.AI Coding Plan
- [ ] Project Bash permission set up (`.claude/settings.local.json` has `"Bash(opencode:*)"`) — or will run inline
- [ ] Model chosen: `glm-5` for complex tasks, `glm-4.7` for simple/routine ones
- [ ] Task is clearly bounded — GLM knows exactly what files to create/modify
- [ ] Relevant file contents included in Context section
- [ ] Output target files specified in Constraints
- [ ] Session file created at `.glm/<task-slug>-<timestamp>.md`
- [ ] `opencode run` executed (background subagent if permission set up, inline otherwise)
- [ ] Verified GLM's output before considering the task done (Claude reviews, not just rubber-stamps)
