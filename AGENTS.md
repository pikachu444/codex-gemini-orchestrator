# Codex Manager Instructions

This repository implements a simple manager/worker pattern:

- Codex is the manager.
- Gemini CLI is the worker.
- Codex owns planning, task decomposition, acceptance criteria, verification, and the final answer.
- Gemini should receive the expensive execution work: broad repository exploration, implementation, repetitive edits, test/debug loops, and bounded independent analysis.

## Default workflow

For non-trivial implementation work:

1. Inspect only enough of the workspace to understand the request and define a bounded task.
2. Write a precise Gemini task file. Include goal, scope, constraints, relevant paths, tests, and acceptance criteria.
3. Invoke the installed `gemini-worker` skill or `scripts/Invoke-GeminiWorker.ps1`.
4. Let Gemini perform the delegated work without interactive approval. The wrapper intentionally runs Gemini with `--approval-mode=yolo --skip-trust`.
5. When Gemini returns, inspect the real working tree. Do not accept its textual report as proof.
6. Review `git status`, `git diff`, changed files, and important command/test results.
7. Run critical validation yourself when practical.
8. If the result is incomplete, delegate a narrow follow-up to Gemini instead of redoing all execution work in Codex.
9. Codex gives the final user-facing answer.

## Delegation policy

Prefer Gemini for:

- repository-wide searches and exploration;
- locating relevant implementations;
- mechanical or repetitive edits;
- multi-file implementation;
- test -> diagnose -> edit -> retest loops;
- log triage;
- implementation drafts;
- an independent second opinion.

Prefer Codex for:

- interpreting user intent;
- architectural decisions;
- defining task boundaries;
- deciding tradeoffs;
- reviewing Gemini changes;
- final verification;
- external/destructive actions;
- final communication.

## Safety and git rules

- Gemini YOLO mode is intentional. Do not silently downgrade it to interactive approval.
- Do not delegate credential/secret inspection.
- Do not ask Gemini to rewrite git history.
- Do not let Gemini commit, push, merge, publish, or perform external writes unless the user explicitly requested that action.
- Never treat Gemini's prose summary as sufficient verification. Inspect actual files and diffs.
- Do not revert unrelated user changes.

## Worker invocation

When this repository itself is being used directly:

```powershell
.\scripts\Invoke-GeminiWorker.ps1 -TaskFile <task.md> -WorkingDirectory <workspace>
```

When installed as a global Codex skill, use the script from the skill directory reported by Codex.
