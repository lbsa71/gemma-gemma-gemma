#Requires -Version 5.1
<#
.SYNOPSIS
  Start / stop Open WebUI (Docker) and verify it can reach llama-server on the host.

.PARAMETER Action
  up | down | logs | verify
#>
[CmdletBinding()]
param(
    [ValidateSet("up", "down", "logs", "verify")]
    [string] $Action = "up"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ComposeFile = Join-Path $RepoRoot "docker-compose.yml"

function Test-DockerEngine {
    docker info 1>$null 2>$null
    return $LASTEXITCODE -eq 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker CLI not found. Install Docker Desktop and ensure 'C:\Program Files\Docker\Docker\resources\bin' is on PATH, then start Docker Desktop."
}

Set-Location $RepoRoot

switch ($Action) {
    "up" {
        if (-not (Test-DockerEngine)) {
            Write-Host "Docker engine is not running. Start Docker Desktop from the Start menu, wait until it says 'Engine running', then re-run:" -ForegroundColor Yellow
            Write-Host "  .\scripts\docker-open-webui.ps1 -Action up" -ForegroundColor White
            exit 1
        }
        docker compose -f $ComposeFile up -d
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Host ""
        Write-Host "Open WebUI: http://localhost:3000" -ForegroundColor Green
        Write-Host "Ensure llama-server is up on the host. For Docker, bind it to all interfaces, e.g.:" -ForegroundColor DarkGray
        Write-Host '  .\scripts\start-llama-server.ps1 -ListenAddress 0.0.0.0 -Port 8080' -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Verify backend reachability:" -ForegroundColor Cyan
        Write-Host "  .\scripts\docker-open-webui.ps1 -Action verify" -ForegroundColor White
    }
    "down" {
        docker compose -f $ComposeFile down
    }
    "logs" {
        docker compose -f $ComposeFile logs -f open-webui
    }
    "verify" {
        if (-not (Test-DockerEngine)) {
            Write-Error "Docker engine is not running."
        }
        $llama = "http://127.0.0.1:8080/v1/models"
        Write-Host "Host -> llama-server: $llama" -ForegroundColor Cyan
        try {
            $r = Invoke-WebRequest -Uri $llama -UseBasicParsing -TimeoutSec 15
            Write-Host "  OK ($($r.StatusCode), $($r.RawContentLength) bytes)" -ForegroundColor Green
        } catch {
            Write-Host "  FAILED: $_" -ForegroundColor Red
            Write-Host "  Start llama-server first (use -ListenAddress 0.0.0.0 if the container test below fails)." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Container -> host.docker.internal:8080/v1/models" -ForegroundColor Cyan
        $psOut = docker compose -f $ComposeFile ps --status running --services 2>$null
        if ($psOut -notcontains "open-webui") {
            Write-Host "  SKIP: open-webui container is not running (run: .\scripts\docker-open-webui.ps1 -Action up)" -ForegroundColor Yellow
        } else {
            $py = "import urllib.request as u`ntry:`n r=u.urlopen('http://host.docker.internal:8080/v1/models',timeout=15)`n b=r.read(500)`n print('  OK',r.status,len(b),'bytes')`nexcept Exception as e:`n print('  FAILED',e)"
            docker compose -f $ComposeFile exec -T open-webui python -c $py
            if ($LASTEXITCODE -ne 0) { Write-Host "  docker compose exec failed (exit $LASTEXITCODE)" -ForegroundColor Red }
        }
        Write-Host ""
        Write-Host "Open WebUI UI: http://localhost:3000" -ForegroundColor Green
        Write-Host "Admin > Connections > OpenAI: URL should be http://host.docker.internal:8080/v1 (pre-seeded via compose env on first install; if you already configured WebUI, adjust in UI)." -ForegroundColor DarkGray
    }
}
