#Requires -Version 5.1
<#
.SYNOPSIS
  Start llama-server (TurboQuant fork) for Gemma 4 26B-A4B GGUF + optional vision.

.DESCRIPTION
  Resolves paths from this repo layout, validates binaries and model files, then
  launches llama-server with conservative TurboQuant KV (q8_0 K + turbo4 V).

.EXAMPLE
  .\scripts\start-llama-server.ps1

.EXAMPLE
  .\scripts\start-llama-server.ps1 -Multimodal -Port 8080

.EXAMPLE
  .\scripts\start-llama-server.ps1 -Model "D:\other\model.gguf" -Ngl 80

.PARAMETER ListenAddress
  HTTP bind address (default 127.0.0.1). Use 0.0.0.0 to accept LAN connections.

.PARAMETER Port
  TCP port for the OpenAI-compatible HTTP API (default 8080).

.PARAMETER Ngl
  Layers offloaded to GPU (-ngl). Lower if you hit VRAM limits.

.PARAMETER Context
  Context size (-c). Default 8192; raise only if you have headroom.

.PARAMETER Multimodal
  Load vision projector and Gemma 4 image / micro-batch settings.

.PARAMETER Model
  Override path to the main .gguf (default: models\gemma-4-26B-A4B-it-GGUF\…Q2_K_XL.gguf).

.PARAMETER Mmproj
  Override path to mmproj .gguf when -Multimodal is set (default: mmproj-BF16.gguf next to the model).
#>
[CmdletBinding()]
param(
    [string] $ListenAddress = "127.0.0.1",
    [int] $Port = 8080,
    [int] $Ngl = 99,
    [int] $Context = 8192,
    [switch] $Multimodal,
    [string] $Model = "",
    [string] $Mmproj = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
}

$RepoRoot = Split-Path $PSScriptRoot -Parent
$DefaultModelDir = Join-Path $RepoRoot "models\gemma-4-26B-A4B-it-GGUF"
$DefaultModel = Join-Path $DefaultModelDir "gemma-4-26B-A4B-it-UD-Q2_K_XL.gguf"
$DefaultMmproj = Join-Path $DefaultModelDir "mmproj-BF16.gguf"
$Exe = Join-Path $RepoRoot "llama-cpp-turboquant\build\bin\Release\llama-server.exe"

$ModelPath = if ($Model) { $Model } else { $DefaultModel }
$MmprojPath = if ($Mmproj) { $Mmproj } else { $DefaultMmproj }

Write-Host ""
Write-Host "  Gemma 4 + TurboQuant  " -NoNewline -ForegroundColor DarkCyan
Write-Host "llama-server" -ForegroundColor White
Write-Host "  $($RepoRoot.TrimEnd('\'))" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $Exe)) {
    Write-Warn "Missing server binary:"
    Write-Host "  $Exe" -ForegroundColor Gray
    Write-Warn "Build first: .\scripts\build-llama-turboquant-cuda.ps1"
    Write-Host "  (If policy blocks scripts: see README or run scripts\fix-powershell-execution-policy.ps1 once with Bypass.)" -ForegroundColor DarkGray
    exit 1
}

if (-not (Test-Path $ModelPath)) {
    Write-Warn "Missing model GGUF:"
    Write-Host "  $ModelPath" -ForegroundColor Gray
    Write-Warn "Download with hf (see README), or pass -Model `"<path>`""
    exit 1
}

if ($Multimodal -and -not (Test-Path $MmprojPath)) {
    Write-Warn "Multimodal requested but missing mmproj:"
    Write-Host "  $MmprojPath" -ForegroundColor Gray
    Write-Warn "Download mmproj-BF16.gguf into the model folder, or pass -Mmproj `"<path>`""
    exit 1
}

Write-Step "Binary"
Write-Host "  $Exe" -ForegroundColor Gray
Write-Step "Model"
Write-Host "  $ModelPath" -ForegroundColor Gray
if ($Multimodal) {
    Write-Step "Vision (mmproj)"
    Write-Host "  $MmprojPath" -ForegroundColor Gray
}

$serverArgs = @(
    "-m", $ModelPath,
    "-ngl", "$Ngl",
    "-c", "$Context",
    "-fa", "on",
    "--jinja",
    "--cache-type-k", "q8_0",
    "--cache-type-v", "turbo4",
    "--host", $ListenAddress,
    "--port", "$Port"
)

if ($Multimodal) {
    $serverArgs += @(
        "--mmproj", $MmprojPath,
        "--image-min-tokens", "1120",
        "--image-max-tokens", "1120",
        "-ub", "2048"
    )
}

Write-Host ""
Write-Ok "OpenAI-compatible API: http://${ListenAddress}:$Port/v1"
Write-Host "  Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

& $Exe @serverArgs
