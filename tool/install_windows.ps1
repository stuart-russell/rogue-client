# Installs (or updates) the per-user copy used by the in-app updater.
#
#   .\tool\install_windows.ps1           # install the current release build
#   .\tool\install_windows.ps1 -Build    # build first
#
# Layout (no admin, no UAC):
#   %LOCALAPPDATA%\Programs\Rogue\
#     app-1.2.0\
#     current -> app-1.2.0   (junction)
#
# The app updates by extracting a new app-<version> folder, repointing `current`
# and relaunching; user data stays in %APPDATA%\app.rogue\Rogue.
param(
  [switch]$Build
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspec = Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)') {
  throw 'Could not read the version from pubspec.yaml.'
}
$version = $Matches[1]

if ($Build) {
  & (Join-Path $PSScriptRoot 'build_windows.ps1')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$release = Join-Path $projectRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'rogue.exe'))) {
  throw "No release build at $release. Run tool\build_windows.ps1 first."
}

$root = Join-Path $env:LOCALAPPDATA 'Programs\Rogue'
$target = Join-Path $root "app-$version"
$current = Join-Path $root 'current'

New-Item -ItemType Directory -Force -Path $root | Out-Null
if (Test-Path $target) { Remove-Item $target -Recurse -Force }
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $target -Recurse -Force

if (Test-Path $current) {
  # rmdir removes the junction only, never the folder it points at.
  & cmd /c rmdir $current | Out-Null
}
& cmd /c mklink /J $current $target | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Could not create the junction at $current." }

# Start-menu shortcut, so the installed copy is easy to launch after updates.
$shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Rogue.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $current 'rogue.exe'
$shortcut.WorkingDirectory = $current
$shortcut.Description = 'Rogue IPTV client'
$shortcut.Save()

Write-Host "Installed Rogue $version"
Write-Host "  app:      $target"
Write-Host "  launcher: $current\rogue.exe"
Write-Host "  shortcut: $shortcutPath"
Write-Host "  data:     $env:APPDATA\app.rogue\Rogue"
Write-Host ''
Write-Host 'Uninstall: delete the Programs\Rogue folder and the shortcut.'
