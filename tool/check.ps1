# One command to verify a change: format check, analyzer, tests.
#
#   .\tool\check.ps1        # verify (fails if formatting would change)
#   .\tool\check.ps1 -Fix   # apply formatting first, then verify
param(
  [switch]$Fix
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Resolve-Tool([string]$Name, [string]$Fallback) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  if ($Fallback -and (Test-Path $Fallback)) { return $Fallback }
  return $null
}

function Resolve-Flutter {
  $command = Get-Command flutter -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $candidates = @()
  if ($env:FLUTTER_ROOT) { $candidates += (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat') }
  $candidates += @(
    (Join-Path $env:LOCALAPPDATA 'sdks\flutter\bin\flutter.bat'),
    'C:\src\flutter\bin\flutter.bat',
    (Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) { return $candidate }
  }
  throw 'Flutter was not found. Add it to PATH or set FLUTTER_ROOT.'
}

$flutter = Resolve-Flutter
$flutterDir = Split-Path -Parent $flutter
$dart = Resolve-Tool 'dart' (Join-Path $flutterDir 'dart.bat')

function Invoke-Step([string]$Label, [scriptblock]$Action) {
  Write-Host ""
  Write-Host "==> $Label" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: $Label" -ForegroundColor Red
    exit $LASTEXITCODE
  }
}

if ($Fix) {
  Invoke-Step 'dart format' { & $dart format lib test tool }
} else {
  Invoke-Step 'dart format (check only)' {
    & $dart format --output=none --set-exit-if-changed lib test tool
  }
}

Invoke-Step 'flutter analyze' { & $flutter analyze }
Invoke-Step 'flutter test' { & $flutter test --reporter compact }

Write-Host ""
Write-Host "All checks passed." -ForegroundColor Green
