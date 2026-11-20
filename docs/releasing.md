# Releasing

Releases are **version-driven**. Nothing is published unless `pubspec.yaml`
changes version.

## Cut a release

```powershell
# 1. bump the version (name + build)
#    version: 0.3.2+8      ← minor/patch per change, always increment the build
# 2. run the checks
tool/check.ps1
# 3. commit and push to main
git commit -am "Rogue 0.3.2"
git push origin main
```

`.github/workflows/release.yml` then:

1. `prepare` reads the version and checks whether `v<name>` exists.
   - existing tag → run only `checks` (no build, no release).
   - new tag → continue.
2. Builds Windows (bundle, zip, Inno installer) and the universal APK, with the
   version and update-manifest URL injected.
3. `publish` writes release notes (tag message if annotated, otherwise commit
   subjects since the last release), generates `manifest.json`, creates the tag
   at the built commit and publishes the GitHub release.

Artifacts (stable names, no version):

- `rogue-client-setup.exe` — Windows installer, per-user, creates the
  `app-<version>` + `current` junction layout used by the updater.
- `rogue-client-windows.zip` — portable bundle; also what the updater downloads.
- `rogue-client.apk` — universal Android package.
- `manifest.json` — consumed by Settings → Updates.

## Version rules

- `AppVersion` (`lib/updates/app_version.dart`) parses `major.minor.patch+build`;
  comparisons use semver then build. **Always increment the build** so Android's
  `versionCode` rises.
- Installed apps compare their embedded `ROGUE_VERSION` against the manifest.
  Build scripts inject it from `pubspec.yaml`.
- Releasing a version older than an installed one will not offer an update.

## Signing (Android)

Android only installs updates signed with the same key. CI signs with the
repository secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEY_PROPERTIES`
(base64 of `android/release.jks` and the contents of `android/key.properties`).
Local release builds use the same files. `storeFile=release.jks` is resolved
from `android/`, and the workflow decodes the keystore there.

Losing the keystore means installed apps can never be updated again — keep the
backup (`%USERPROFILE%\rogue-keystore-backup` on the original machine) off-site
too. Changing keys forces a one-time uninstall/reinstall.

## Windows install layout

`%LOCALAPPDATA%\Programs\Rogue\app-<version>` plus `current` (junction) and a
Start-menu shortcut. `tool/install_windows.ps1` creates it for local builds; the
Inno installer does the same in production. Updates extract a new folder,
repoint `current`, prune older folders and relaunch.

## Icons

`tool/make_icons.ps1` draws the R mark and writes Android legacy + adaptive
icons, the TV banner, the Windows `.ico` and `assets/branding/*.png`. Re-run it
after changing the mark.

## Manual manifest

```powershell
node tool/make_manifest.mjs --version 0.3.2 --build 8 --tag v0.3.2 `
  --repo owner/repo --windows dist/rogue-client-windows.zip `
  --android dist/rogue-client.apk
```

## Troubleshooting

- **Workflow skipped the build** — the tag already exists. Bump the version
  (including the build number) and push again.
- **Android refuses to install an update** — signature mismatch. Confirm the CI
  secrets are set and that the installed APK came from a release signed with the
  same key.
- **Release published without presets** — `ROGUE_PORTALS` and
  `ROGUE_DEFAULT_SERVER` secrets are missing.
