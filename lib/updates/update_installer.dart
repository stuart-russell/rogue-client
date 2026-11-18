import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';

import 'update_manifest.dart';

enum InstallOutcome {
  /// Staged and ready; [UpdateInstaller.restart] finishes the job.
  staged,

  /// Handed to the OS (Android package installer sheet).
  handedOff,

  /// This copy cannot update itself; the artifact was revealed instead.
  manual,
}

/// Applies a downloaded artifact. The Windows implementation swaps a versioned
/// folder behind a `current` junction; Android hands the APK to the system.
abstract class UpdateInstaller {
  bool get canSelfInstall;

  /// Label for the primary action, e.g. `Install update` or `Download zip`.
  String get actionLabel;

  Future<InstallOutcome> stage({
    required File artifact,
    required UpdateManifest manifest,
  });

  /// Windows only: launch the staged build and quit. No-op elsewhere.
  Future<void> restart() async {}

  /// Fallback for copies that cannot self-update.
  Future<void> reveal(File artifact, UpdateManifest manifest) async {}
}

UpdateInstaller installerForCurrentPlatform() {
  if (Platform.isWindows) return WindowsUpdateInstaller();
  if (Platform.isAndroid) return AndroidUpdateInstaller();
  return UnsupportedUpdateInstaller();
}

/// Layout used by `tool/install_windows.ps1`:
///
/// ```
/// %LOCALAPPDATA%\Programs\Rogue\
///   app-1.2.0\  app-1.3.0\
///   current -> app-1.3.0   (junction)
/// ```
class WindowsUpdateInstaller extends UpdateInstaller {
  WindowsUpdateInstaller({this.executableOverride});

  static const String _separator = '\\';
  static const String _executableName = 'rogue.exe';

  final File? executableOverride;

  File get executable => executableOverride ?? File(Platform.resolvedExecutable);

  /// `...\Programs\Rogue\app-1.2.0\rogue.exe` → `...\Programs\Rogue`.
  Directory? get _installRoot {
    final appDir = executable.parent;
    final name = _leaf(appDir.path);
    if (!name.startsWith('app-')) return null;
    return appDir.parent;
  }

  Directory get _currentLink {
    final root = _installRoot;
    if (root == null) return Directory('');
    return Directory(_child(root.path, 'current'));
  }

  @override
  bool get canSelfInstall => _installRoot != null && _installRoot!.existsSync();

  @override
  String get actionLabel => canSelfInstall ? 'Install update' : 'Download zip';

  @override
  Future<InstallOutcome> stage({
    required File artifact,
    required UpdateManifest manifest,
  }) async {
    final root = _installRoot;
    if (root == null) {
      await reveal(artifact, manifest);
      return InstallOutcome.manual;
    }

    final target = Directory(_child(root.path, 'app-${manifest.version}'));
    if (await target.exists()) await target.delete(recursive: true);
    await target.create(recursive: true);

    // Zip extraction is CPU-heavy; keep it off the UI isolate.
    await Isolate.run(() => extractFileToDisk(artifact.path, target.path));

    final stagedExe = File(_child(target.path, _executableName));
    if (!await stagedExe.exists()) {
      await target.delete(recursive: true);
      throw StateError('The update archive does not contain $_executableName.');
    }

    await _pointCurrentAt(target);
    await _prune(root, keep: {target.path, executable.parent.path});
    return InstallOutcome.staged;
  }

  Future<void> _pointCurrentAt(Directory target) async {
    final link = _currentLink;
    if (await link.exists()) {
      // `rmdir` removes the junction itself, never the folder it points at.
      await Process.run('cmd', ['/c', 'rmdir', link.path]);
    }
    final result = await Process.run('cmd', ['/c', 'mklink', '/J', link.path, target.path]);
    if (result.exitCode != 0) {
      throw StateError('Could not switch the install to ${target.path}: ${result.stderr}');
    }
  }

  Future<void> _prune(Directory root, {required Set<String> keep}) async {
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = _leaf(entity.path);
        if (!name.startsWith('app-')) continue;
        if (keep.contains(entity.path)) continue;
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // Still running from it, or locked by an indexer. Next update retries.
        }
      }
    } catch (_) {
      // Pruning is housekeeping; never fail an update because of it.
    }
  }

  @override
  Future<void> restart() async {
    final root = _installRoot;
    if (root == null) return;
    final exe = File(_child(_currentLink.path, _executableName));
    if (!await exe.exists()) return;
    await Process.start(exe.path, const [], mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  Future<void> reveal(File artifact, UpdateManifest manifest) async {
    await Process.start('explorer.exe', ['/select,', artifact.path]);
  }

  static String _child(String parent, String name) => '$parent$_separator$name';

  static String _leaf(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }
}

/// Hands the downloaded APK to the system package installer.
class AndroidUpdateInstaller extends UpdateInstaller {
  static const MethodChannel _channel = MethodChannel('app.rogue.client/updater');

  @override
  bool get canSelfInstall => true;

  @override
  String get actionLabel => 'Install update';

  @override
  Future<InstallOutcome> stage({
    required File artifact,
    required UpdateManifest manifest,
  }) async {
    final started = await _channel.invokeMethod<bool>('installApk', {
      'path': artifact.path,
    });
    if (started != true) {
      throw StateError(
        'Android needs permission to install this update. Allow "Install unknown apps" for Rogue and try again.',
      );
    }
    return InstallOutcome.handedOff;
  }
}

class UnsupportedUpdateInstaller extends UpdateInstaller {
  @override
  bool get canSelfInstall => false;

  @override
  String get actionLabel => 'Download';

  @override
  Future<InstallOutcome> stage({
    required File artifact,
    required UpdateManifest manifest,
  }) async {
    await reveal(artifact, manifest);
    return InstallOutcome.manual;
  }

  @override
  Future<void> reveal(File artifact, UpdateManifest manifest) async {}
}
