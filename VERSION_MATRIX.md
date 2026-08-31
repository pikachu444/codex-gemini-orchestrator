# Version matrix

This project intentionally pins the command-line tools used by the default installer so behavior is reproducible.

| Component | Default tested baseline | Setup behavior |
|---|---:|---|
| Codex CLI | `0.151.0` | installed by `Setup.ps1` |
| Gemini CLI | `0.57.0` | installed by `Setup.ps1` |
| Node.js | `20+` | existing version reused; LTS installed with winget if missing/too old |
| PowerShell | Windows PowerShell 5.1+ | used for setup/wrapper scripts |
| OS | Windows 11 | primary target |
| Codex Desktop | not pinned | optional; restart after skill installation |

## Why pin CLI versions?

Both Codex CLI and Gemini CLI evolve quickly. Pinning the default setup gives us one known combination to debug when something breaks.

To install current npm releases instead:

```powershell
.\scripts\Setup.ps1 -Latest
```

## Important Gemini CLI behavior used by this project

The worker wrapper relies on these Gemini CLI options:

```text
--approval-mode yolo
--skip-trust
--output-format json
--prompt <short headless instruction>
```

The full delegated task is passed through stdin. Gemini CLI documents that stdin input can be combined with `--prompt`, which avoids placing a long task body on the Windows command line.

## Upgrade policy

When changing the pinned versions:

1. Run `scripts/Test-Environment.ps1`.
2. Run one read-only Gemini worker task.
3. Run one task that edits a disposable test repository.
4. Confirm YOLO tool execution does not stop for approvals.
5. Confirm `raw.json` still contains a `response` field or update the wrapper parser.
6. Confirm Codex can inspect the modified workspace after the worker exits.
7. Only then update the pinned versions in `scripts/Setup.ps1` and this file.
