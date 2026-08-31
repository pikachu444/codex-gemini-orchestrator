[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$Model = "auto",

    [string]$RunRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $TaskFile -PathType Leaf)) {
    throw "Task file not found: $TaskFile"
}
if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
    throw "Working directory not found: $WorkingDirectory"
}

$taskPath = (Resolve-Path -LiteralPath $TaskFile).Path
$workspace = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$gemini = Get-Command gemini -ErrorAction Stop

if (-not $RunRoot) {
    $RunRoot = Join-Path ([System.IO.Path]::GetTempPath()) "codex-gemini-orchestrator"
}

$runId = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$runDirectory = Join-Path $RunRoot $runId
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

$promptPath = Join-Path $runDirectory "prompt.md"
$rawPath = Join-Path $runDirectory "raw.json"
$resultPath = Join-Path $runDirectory "result.md"
$stderrPath = Join-Path $runDirectory "stderr.txt"
$gitBeforePath = Join-Path $runDirectory "git-before.txt"
$gitAfterPath = Join-Path $runDirectory "git-after.txt"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workerInstructionsPath = Join-Path $repoRoot "GEMINI.md"
$workerInstructions = ""
if (Test-Path -LiteralPath $workerInstructionsPath -PathType Leaf) {
    $workerInstructions = Get-Content -LiteralPath $workerInstructionsPath -Raw -Encoding UTF8
}
$task = Get-Content -LiteralPath $taskPath -Raw -Encoding UTF8

$combinedPrompt = @"
# Worker role

$workerInstructions

# Specific delegated task

$task
"@

Set-Content -LiteralPath $promptPath -Value $combinedPrompt -Encoding UTF8

function Save-GitStatus {
    param(
        [string]$Directory,
        [string]$Destination
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Set-Content -LiteralPath $Destination -Value "git is not installed or not on PATH." -Encoding UTF8
        return
    }

    Push-Location $Directory
    try {
        $inside = (& git rev-parse --is-inside-work-tree 2>$null | Out-String).Trim()
        if ($inside -ne "true") {
            Set-Content -LiteralPath $Destination -Value "Working directory is not a git worktree." -Encoding UTF8
            return
        }

        $status = & git status --short --branch 2>&1 | Out-String
        Set-Content -LiteralPath $Destination -Value $status -Encoding UTF8
    }
    finally {
        Pop-Location
    }
}

Save-GitStatus -Directory $workspace -Destination $gitBeforePath

$geminiArgs = @(
    "--approval-mode", "yolo",
    "--skip-trust",
    "--output-format", "json"
)
if ($Model -and $Model -ne "auto") {
    $geminiArgs += @("--model", $Model)
}
$geminiArgs += @(
    "--prompt",
    "Execute the delegated task provided on stdin. Work directly in the current workspace. Do the implementation and validation, then return a concise completion report."
)

Write-Host "[gemini-worker] Workspace: $workspace"
Write-Host "[gemini-worker] Run directory: $runDirectory"
Write-Host "[gemini-worker] Starting Gemini CLI in YOLO mode..."

$exitCode = 1
$outputLines = @()
Push-Location $workspace
try {
    $outputLines = $combinedPrompt | & $gemini.Source @geminiArgs 2> $stderrPath
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

$rawText = ($outputLines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
Set-Content -LiteralPath $rawPath -Value $rawText -Encoding UTF8
Save-GitStatus -Directory $workspace -Destination $gitAfterPath

$responseText = $rawText
try {
    $payload = $rawText | ConvertFrom-Json -ErrorAction Stop
    if ($null -ne $payload.response) {
        $responseText = [string]$payload.response
    }
}
catch {
    # Keep the raw output when a future Gemini version changes the JSON schema
    # or when the command fails before producing valid JSON.
}

$stderrText = ""
if (Test-Path -LiteralPath $stderrPath) {
    $stderrText = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
}

$result = @"
# Gemini worker result

- Exit code: `$exitCode`
- Workspace: `$workspace`
- Run directory: `$runDirectory`
- Approval mode: `yolo`
- Folder trust: skipped for this headless worker session

## Gemini response

$responseText

## stderr

```text
$stderrText
```

## Artifacts

- Prompt: `$promptPath`
- Raw JSON: `$rawPath`
- Git status before: `$gitBeforePath`
- Git status after: `$gitAfterPath`
"@

Set-Content -LiteralPath $resultPath -Value $result -Encoding UTF8

Write-Host "[gemini-worker] Exit code: $exitCode"
Write-Host "[gemini-worker] Result: $resultPath"
Write-Output $runDirectory

if ($exitCode -ne 0) {
    exit $exitCode
}
