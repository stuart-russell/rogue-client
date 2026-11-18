# Builds the Windows release with the settings this app needs.
#
#   .\tool\build_windows.ps1            # build
#   .\tool\build_windows.ps1 -Zip       # build + dist\Rogue-<version>-win-x64.zip
#
# Why --no-tree-shake-icons: the release icon shaker drops glyphs that are only
# referenced through dynamic IconData (the player's skip buttons), which leaves
# invisible 40x40 buttons. The full Material Icons font is 1.6 MB - irrelevant
# for a desktop build.
#
# Portal presets are read from the environment so they never live in the repo:
#   $env:ROGUE_PORTALS = "Portal A=http://a:8880|Portal B=https://b"
#   $env:ROGUE_DEFAULT_SERVER = "http://a:8880"
#
# Update checks need a manifest URL, normally injected by CI:
#   $env:ROGUE_UPDATE_MANIFEST = "https://github.com/<owner>/<repo>/releases/latest/download/manifest.json"
param(
  [switch]$Zip
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

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

# The app reports this version and compares it against the update manifest, so
# it must match pubspec.yaml (Android takes versionCode from the same field).
$pubspec = Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)') {
  throw 'Could not read the version from pubspec.yaml.'
}
$version = $Matches[1]

$arguments = @('build', 'windows', '--release', '--no-tree-shake-icons', "--dart-define=ROGUE_VERSION=$version")

if ($env:ROGUE_PORTALS) {
  $arguments += "--dart-define=ROGUE_PORTALS=$($env:ROGUE_PORTALS)"
}
if ($env:ROGUE_DEFAULT_SERVER) {
  $arguments += "--dart-define=ROGUE_DEFAULT_SERVER=$($env:ROGUE_DEFAULT_SERVER)"
}
if ($env:ROGUE_UPDATE_MANIFEST) {
  $arguments += "--dart-define=ROGUE_UPDATE_MANIFEST=$($env:ROGUE_UPDATE_MANIFEST)"
}

if (-not $env:CI) { Write-Host "flutter $($arguments -join ' ')" }
& $flutter @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$release = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$exe = Join-Path $release 'rogue.exe'
Write-Host "Built $exe (version $version)"

if ($Zip) {
  $dist = Join-Path $projectRoot 'dist'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  $zipName = 'rogue-client-windows.zip'
  $zipPath = Join-Path $dist $zipName
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zipPath
  Write-Host "Packed $zipPath"
}
