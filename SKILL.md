---
name: gemini-worker
description: Delegate expensive repository exploration, implementation, repetitive edits, test/debug loops, and bounded analysis to Gemini CLI while Codex remains responsible for planning, review, verification, and the final answer.
---

# Gemini Worker

Use Gemini CLI as an execution worker so Codex can spend its context and quota on planning, judgment, and verification.

## Core rule

For non-trivial coding work, prefer delegating the execution-heavy portion to Gemini when it can be expressed as a bounded task. Codex remains the manager.

Do not require the user to explicitly repeat "use Gemini" on every turn once this workflow is requested for the current task/project.

## Workflow

1. Understand the user's request.
2. Inspect enough context to define a precise delegated task. Do not consume large amounts of Codex context doing exploration that Gemini can perform.
3. Create a UTF-8 Markdown task file containing:
   - objective;
   - relevant context;
   - scope;
   - constraints;
   - expected files or areas to inspect;
   - required tests/validation;
   - acceptance criteria.
4. Run `scripts/Invoke-GeminiWorker.ps1` from this skill directory, with the target repository as `-WorkingDirectory`.
5. The wrapper intentionally runs Gemini using `--approval-mode=yolo --skip-trust --output-format=json`. Do not change this to an interactive approval flow unless the user explicitly asks.
6. Read Gemini's result, then inspect the actual target workspace using `git status` and `git diff`.
7. Verify important changes and tests yourself. Gemini's textual report is not proof.
8. If a fix is incomplete, create a narrow follow-up task and delegate again instead of repeating all implementation work directly in Codex.
9. Give the final response yourself.

## Good delegation targets

- broad codebase exploration;
- locating relevant code and call paths;
- implementing a defined change;
- repetitive/multi-file edits;
- running tests and iterating on failures;
- build failure triage;
- log analysis;
- bounded refactoring;
- independent review or second opinion.

## Keep in Codex

- interpreting ambiguous user intent;
- architecture and tradeoff decisions;
- defining acceptance criteria;
- permission/scope decisions;
- final diff review;
- critical validation;
- destructive or external writes;
- final answer.

## Recommended task template

```markdown
# Delegated task

## Objective
<one concrete objective>

## Workspace
<target workspace>

## Context
<only the context Gemini needs>

## Scope
- Inspect: <paths or areas>
- Edit: <paths or "any in-repo files needed for this task">

## Constraints
- Preserve unrelated changes.
- Do not inspect secrets/credentials.
- Do not commit or push.
- Do not perform external writes.

## Validation
<tests or commands Gemini should run>

## Acceptance criteria
<clear completion conditions>
```

## Invocation example

```powershell
$skillRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$skillRoot\scripts\Invoke-GeminiWorker.ps1" `
  -TaskFile C:\temp\gemini-task.md `
  -WorkingDirectory C:\work\target-repo
```

When Codex is executing this skill, resolve the script relative to the loaded skill location instead of assuming a fixed repository path.

## Failure handling

- `gemini` missing: report that Gemini CLI is not installed or not on PATH.
- Authentication failure: tell the user to run `gemini` interactively once and sign in.
- Network failure: verify Codex sandbox network access and company proxy/policy.
- YOLO blocked by enterprise policy: report the policy failure; do not pretend the worker ran.
- Gemini timeout/failure: narrow the task and retry once when reasonable.
- Incorrect or out-of-scope edits: do not accept them; inspect and repair/revert only the Gemini-caused changes without touching unrelated user work.
