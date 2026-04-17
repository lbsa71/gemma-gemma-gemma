#Requires -Version 5.1
<#
.SYNOPSIS
  Allow running local repo scripts without passing -ExecutionPolicy Bypass each time.

.DESCRIPTION
  Sets ExecutionPolicy to RemoteSigned for CurrentUser (recommended on Windows dev machines).
  Unblocks .ps1 files in this scripts folder if Windows marked them as downloaded from the internet.

  First run must use Bypass (policy is still Restricted):
    powershell -ExecutionPolicy Bypass -File .\scripts\fix-powershell-execution-policy.ps1
#>
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  PowerShell execution policy (CurrentUser)" -ForegroundColor Cyan
Write-Host ""

Write-Host "  Before (all scopes):" -ForegroundColor Gray
Get-ExecutionPolicy -List | ForEach-Object { Write-Host ("    {0,-16} {1}" -f $_.Scope, $_.ExecutionPolicy) }

$cuBefore = Get-ExecutionPolicy -Scope CurrentUser
if ($cuBefore -ne "RemoteSigned") {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    } catch {
        Write-Host "  Set-ExecutionPolicy: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  CurrentUser already RemoteSigned; skipping Set-ExecutionPolicy." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  After (all scopes):" -ForegroundColor Gray
Get-ExecutionPolicy -List | ForEach-Object { Write-Host ("    {0,-16} {1}" -f $_.Scope, $_.ExecutionPolicy) }

$cu = Get-ExecutionPolicy -Scope CurrentUser
if ($cu -in @("RemoteSigned", "Unrestricted", "Bypass")) {
    Write-Host ""
    Write-Host "  CurrentUser is OK for local scripts: $cu" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  CurrentUser policy is still: $cu" -ForegroundColor Yellow
    Write-Host "  If scripts stay blocked (e.g. Group Policy), use per-invocation:" -ForegroundColor Yellow
    Write-Host '    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\<script>.ps1' -ForegroundColor Gray
}

$scriptDir = $PSScriptRoot
$count = 0
Get-ChildItem -Path $scriptDir -Filter "*.ps1" -File | ForEach-Object {
    Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue
    $count++
}
Write-Host ""
Write-Host "  Unblock-File applied under: $scriptDir ($count script(s))" -ForegroundColor Gray

Write-Host ""
Write-Host "  You can now try:" -ForegroundColor DarkCyan
Write-Host "    .\scripts\start-llama-server.ps1" -ForegroundColor White
Write-Host "    .\scripts\build-llama-turboquant-cuda.ps1" -ForegroundColor White
Write-Host ""
