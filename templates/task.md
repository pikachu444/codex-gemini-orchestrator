# Delegated task

## Objective
Describe one concrete result Gemini should produce.

## Workspace
`C:\path\to\target-repository`

## Context
Provide only the context needed to perform the task. Gemini can inspect the repository itself.

## Scope
- Inspect: relevant repository files as needed.
- Edit: files required for this task.

## Constraints
- Preserve unrelated user/Codex changes.
- Do not inspect credentials, secrets, keys, or tokens.
- Do not commit or push.
- Do not rewrite git history.
- Do not perform external writes unless explicitly required.

## Validation
Run the relevant tests/build/lint commands and iterate on failures caused by this task.

## Acceptance criteria
- Requested behavior is implemented.
- Relevant tests pass, or any remaining failure is clearly explained.
- Final report lists files changed and validation performed.
