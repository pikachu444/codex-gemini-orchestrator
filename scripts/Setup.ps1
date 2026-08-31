[CmdletBinding()]
param(
    [switch]$Latest,
    [switch]$SkipCliInstall,
    [switch]$SkipCodexConfig
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$CodexPinnedVersion = "0.151.0"
$GeminiPinnedVersion = "0.57.0"

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Get-NodeMajorVersion {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        return 0
    }
    $version = (& $node.Source --version 2>$null | Out-String).Trim()
    if ($version -match "^v(\d+)") {
        return [int]$Matches[1]
    }
    return 0
}

function Ensure-Node {
    $major = Get-NodeMajorVersion
    if ($major -ge 20) {
        Write-Host "[setup] Node.js $major detected."
        return
    }

    Write-Host "[setup] Node.js 20+ is required."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "Node.js 20+ is missing and winget is unavailable. Install Node.js LTS manually, then rerun this script."
    }

    Write-Host "[setup] Installing Node.js LTS with winget..."
    & $winget.Source install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install Node.js LTS (exit code $LASTEXITCODE)."
    }

    Refresh-ProcessPath
    $major = Get-NodeMajorVersion
    if ($major -lt 20) {
        throw "Node.js installation finished but node 20+ is still not visible in PATH. Open a new terminal and rerun setup."
    }
}

function Install-CLIs {
    Ensure-Node

    $npm = Get-Command npm -ErrorAction Stop
    if ($Latest) {
        $codexPackage = "@openai/codex@latest"
        $geminiPackage = "@google/gemini-cli@latest"
    }
    else {
        $codexPackage = "@openai/codex@$CodexPinnedVersion"
        $geminiPackage = "@google/gemini-cli@$GeminiPinnedVersion"
    }

    Write-Host "[setup] Installing $codexPackage"
    & $npm.Source install --global $codexPackage
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Codex CLI."
    }

    Write-Host "[setup] Installing $geminiPackage"
    & $npm.Source install --global $geminiPackage
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Gemini CLI."
    }

    Refresh-ProcessPath
}

function Install-CodexSkill {
    # Current Codex user-skill root. This is preferred over the deprecated
    # $CODEX_HOME/skills location and is also visible to Codex Desktop.
    $skillRoot = Join-Path $HOME ".agents\skills\gemini-worker"
    Write-Host "[setup] Installing Codex skill to $skillRoot"

    if (Test-Path -LiteralPath $skillRoot) {
        Remove-Item -LiteralPath $skillRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path (Join-Path $skillRoot "scripts") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot "SKILL.md") -Destination (Join-Path $skillRoot "SKILL.md") -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "GEMINI.md") -Destination (Join-Path $skillRoot "GEMINI.md") -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts\Invoke-GeminiWorker.ps1") -Destination (Join-Path $skillRoot "scripts\Invoke-GeminiWorker.ps1") -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts\Test-Environment.ps1") -Destination (Join-Path $skillRoot "scripts\Test-Environment.ps1") -Force
}

function Set-TopLevelTomlValue {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Key,
        [string]$RenderedValue
    )

    # Only inspect lines before the first TOML section. A profile may contain
    # the same key and must not be mistaken for the global value.
    $firstSection = $Lines.Count
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^\s*\[.+\]\s*$") {
            $firstSection = $i
            break
        }
    }

    for ($i = 0; $i -lt $firstSection; $i++) {
        if ($Lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") {
            $Lines[$i] = "$Key = $RenderedValue"
            return
        }
    }

    $Lines.Insert(0, "$Key = $RenderedValue")
}

function Set-SectionTomlValue {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Section,
        [string]$Key,
        [string]$RenderedValue
    )

    $sectionHeader = "[$Section]"
    $sectionIndex = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq $sectionHeader) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1].Trim() -ne "") {
            $Lines.Add("")
        }
        $Lines.Add($sectionHeader)
        $Lines.Add("$Key = $RenderedValue")
        return
    }

    $endIndex = $Lines.Count
    for ($i = $sectionIndex + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^\s*\[.+\]\s*$") {
            $endIndex = $i
            break
        }
    }

    for ($i = $sectionIndex + 1; $i -lt $endIndex; $i++) {
        if ($Lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") {
            $Lines[$i] = "$Key = $RenderedValue"
            return
        }
    }

    $Lines.Insert($sectionIndex + 1, "$Key = $RenderedValue")
}

function Configure-Codex {
    $codexHome = Join-Path $HOME ".codex"
    $configPath = Join-Path $codexHome "config.toml"
    New-Item -ItemType Directory -Path $codexHome -Force | Out-Null

    if (Test-Path -LiteralPath $configPath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backup = "$configPath.bak-$timestamp"
        Copy-Item -LiteralPath $configPath -Destination $backup -Force
        Write-Host "[setup] Backed up Codex config to $backup"
        $existing = Get-Content -LiteralPath $configPath -Encoding UTF8
    }
    else {
        $existing = @()
    }

    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in $existing) {
        $lines.Add([string]$line)
    }

    Set-TopLevelTomlValue -Lines $lines -Key "sandbox_mode" -RenderedValue '"workspace-write"'
    Set-TopLevelTomlValue -Lines $lines -Key "approval_policy" -RenderedValue '"never"'
    Set-SectionTomlValue -Lines $lines -Section "sandbox_workspace_write" -Key "network_access" -RenderedValue "true"

    Set-Content -LiteralPath $configPath -Value $lines -Encoding UTF8
    Write-Host "[setup] Updated Codex config: $configPath"
}

Write-Host ""
Write-Host "=== codex-gemini-orchestrator setup ==="
Write-Host "Repository: $RepoRoot"

if (-not $SkipCliInstall) {
    Install-CLIs
}
else {
    Write-Host "[setup] Skipping CLI installation."
}

Install-CodexSkill

if (-not $SkipCodexConfig) {
    Configure-Codex
}
else {
    Write-Host "[setup] Skipping Codex config changes."
}

Write-Host ""
Write-Host "[setup] Running environment check..."
& (Join-Path $PSScriptRoot "Test-Environment.ps1")

Write-Host ""
Write-Host "Setup complete."
Write-Host "If authentication has not been done yet, run these once:"
Write-Host "  codex"
Write-Host "  gemini"
Write-Host "Then restart Codex CLI/Desktop so it can discover the gemini-worker skill."
