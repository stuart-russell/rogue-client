import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/updates/app_version.dart';
import 'package:rogue/updates/update_installer.dart';
import 'package:rogue/updates/update_manifest.dart';

UpdateManifest _manifest(String version) => UpdateManifest(
  version: AppVersion.parse(version),
  notes: '',
  windows: const ReleaseArtifact(
    url: 'https://example.test/win.zip',
    sha256: 'x',
  ),
);

void main() {
  // Junctions and cmd.exe only exist on Windows; elsewhere the app never uses
  // this installer.
  if (!Platform.isWindows) {
    test('windows installer', () {}, skip: 'Windows only');
    return;
  }

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('rogue-installer');
  });

  tearDown(() {
    try {
      // Break the junction before removing the tree.
      final current = Directory('${root.path}\\current');
      if (current.existsSync()) {
        Process.runSync('cmd', ['/c', 'rmdir', current.path]);
      }
      root.deleteSync(recursive: true);
    } catch (_) {
      // Best effort.
    }
  });

  Directory versionDir(String version) {
    final dir = Directory('${root.path}\\app-$version');
    dir.createSync(recursive: true);
    File('${dir.path}\\rogue.exe').writeAsStringSync('stub $version');
    return dir;
  }

  File zipBuild(String version, {bool includeExe = true}) {
    final source = Directory.systemTemp.createTempSync('rogue-zip');
    if (includeExe) {
      File('${source.path}\\rogue.exe').writeAsStringSync('new build $version');
    }
    File('${source.path}\\flutter_windows.dll').writeAsStringSync('dll');

    final zipPath = '${root.path}\\update-$version.zip';
    final encoder = ZipFileEncoder()..create(zipPath);
    for (final entity in source.listSync()) {
      if (entity is File) {
        encoder.addFileSync(entity, entity.uri.pathSegments.last);
      }
    }
    encoder.closeSync();
    return File(zipPath);
  }

  test('stages into a new version folder and repoints current', () async {
    final running = versionDir('1.0.0');
    final old = versionDir('0.9.0');
    final installer = WindowsUpdateInstaller(
      executableOverride: File('${running.path}\\rogue.exe'),
    );

    expect(installer.canSelfInstall, isTrue);

    final outcome = await installer.stage(
      artifact: zipBuild('1.1.0'),
      manifest: _manifest('1.1.0'),
    );

    expect(outcome, InstallOutcome.staged);
    expect(File('${root.path}\\app-1.1.0\\rogue.exe').existsSync(), isTrue);
    expect(
      File('${root.path}\\app-1.1.0\\flutter_windows.dll').existsSync(),
      isTrue,
    );

    // `current` is a junction to the new build.
    final current = Directory('${root.path}\\current');
    expect(current.existsSync(), isTrue);
    expect(
      File('${current.path}\\rogue.exe').readAsStringSync(),
      'new build 1.1.0',
    );

    // The previous release is pruned, the running one is left alone.
    expect(old.existsSync(), isFalse);
    expect(running.existsSync(), isTrue);
  });

  test('refuses an archive without the executable', () async {
    final running = versionDir('1.0.0');
    final installer = WindowsUpdateInstaller(
      executableOverride: File('${running.path}\\rogue.exe'),
    );

    await expectLater(
      installer.stage(
        artifact: zipBuild('1.1.0', includeExe: false),
        manifest: _manifest('1.1.0'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(Directory('${root.path}\\app-1.1.0').existsSync(), isFalse);
  });

  test('cannot self-install when the layout is not managed', () async {
    final plain = Directory('${root.path}\\plain')..createSync(recursive: true);
    final exe = File('${plain.path}\\rogue.exe')
      ..writeAsStringSync('dev build');
    final installer = WindowsUpdateInstaller(executableOverride: exe);

    expect(installer.canSelfInstall, isFalse);
    expect(installer.actionLabel, 'Download zip');
  });
}
