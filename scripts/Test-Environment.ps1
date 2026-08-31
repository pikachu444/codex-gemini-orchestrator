[CmdletBinding()]
param(
    [switch]$TestGeminiAuth
)

$ErrorActionPreference = "Continue"

function Get-CommandVersion {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{
            Name = $Name
            Found = $false
            Version = "missing"
            Path = ""
        }
    }

    try {
        $versionText = (& $command.Source @Arguments 2>&1 | Select-Object -First 1 | Out-String).Trim()
    }
    catch {
        $versionText = "version check failed: $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        Name = $Name
        Found = $true
        Version = $versionText
        Path = $command.Source
    }
}

$results = @(
    Get-CommandVersion -Name "node" -Arguments @("--version")
    Get-CommandVersion -Name "npm" -Arguments @("--version")
    Get-CommandVersion -Name "codex" -Arguments @("--version")
    Get-CommandVersion -Name "gemini" -Arguments @("--version")
    Get-CommandVersion -Name "git" -Arguments @("--version")
)

Write-Host ""
Write-Host "=== Codex + Gemini environment ==="
$results | Format-Table -AutoSize

$requiredNames = @("node", "npm", "codex", "gemini")
$missing = @($results | Where-Object { ($requiredNames -contains $_.Name) -and (-not $_.Found) })

$git = $results | Where-Object { $_.Name -eq "git" }
if (-not $git.Found) {
    Write-Warning "git is not installed. The worker still runs, but before/after git status capture will be unavailable."
}

$node = $results | Where-Object { $_.Name -eq "node" }
if ($node.Found -and $node.Version -match "v(\d+)") {
    $major = [int]$Matches[1]
    if ($major -lt 20) {
        Write-Warning "Node.js $major detected. Gemini CLI requires Node.js 20 or newer."
    }
}

$skillPath = Join-Path $HOME ".agents\skills\gemini-worker\SKILL.md"
if (Test-Path -LiteralPath $skillPath) {
    Write-Host "Codex skill: installed ($skillPath)"
}
else {
    Write-Warning "Codex gemini-worker skill is not installed at $skillPath"
}

$configPath = Join-Path $HOME ".codex\config.toml"
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw
    $hasNetwork = $config -match '(?m)^\s*network_access\s*=\s*true\s*$'
    $hasNever = $config -match '(?m)^\s*approval_policy\s*=\s*["'']never["'']\s*$'
    Write-Host "Codex config: $configPath"
    Write-Host "  approval_policy=never: $hasNever"
    Write-Host "  network_access=true:   $hasNetwork"
}
else {
    Write-Warning "Codex config not found: $configPath"
}

if ($TestGeminiAuth -and (Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Testing Gemini headless authentication/network with a tiny request..."
    try {
        $raw = & gemini --skip-trust --output-format json --prompt "Reply exactly READY." 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $json = $raw | ConvertFrom-Json -ErrorAction Stop
            Write-Host "Gemini headless test: success"
            Write-Host "Response: $($json.response)"
        }
        else {
            Write-Warning "Gemini headless test failed with exit code $LASTEXITCODE"
            Write-Host $raw
        }
    }
    catch {
        Write-Warning "Gemini headless test failed: $($_.Exception.Message)"
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing required commands: $($missing.Name -join ', ')"
    exit 1
}

Write-Host ""
Write-Host "Environment check completed."
