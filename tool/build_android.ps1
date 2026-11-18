# Builds the release APK with the same defines as the Windows build.
#
#   .\tool\build_android.ps1
#
# Signing: add android\key.properties + a keystore to sign with your own key.
# Without it the APK is debug-signed, which is fine for a first install but
# cannot upgrade an APK signed by a different machine's debug key.
param(
  [string]$TargetPlatform = ''
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

$pubspec = Get-Content (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)') {
  throw 'Could not read the version from pubspec.yaml.'
}
$version = $Matches[1]

$arguments = @('build', 'apk', '--release', "--dart-define=ROGUE_VERSION=$version")
if ($TargetPlatform) {
  $arguments += @('--target-platform', $TargetPlatform)
}
if ($env:ROGUE_PORTALS) {
  $arguments += "--dart-define=ROGUE_PORTALS=$($env:ROGUE_PORTALS)"
}
if ($env:ROGUE_DEFAULT_SERVER) {
  $arguments += "--dart-define=ROGUE_DEFAULT_SERVER=$($env:ROGUE_DEFAULT_SERVER)"
}
if ($env:ROGUE_UPDATE_MANIFEST) {
  $arguments += "--dart-define=ROGUE_UPDATE_MANIFEST=$($env:ROGUE_UPDATE_MANIFEST)"
}

Write-Host "flutter $($arguments -join ' ')"
& $flutter @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Built build\app\outputs\flutter-apk\app-release.apk (version $version)"
