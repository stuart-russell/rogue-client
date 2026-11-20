import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/updates/app_version.dart';
import 'package:rogue/updates/update_controller.dart';
import 'package:rogue/updates/update_installer.dart';
import 'package:rogue/updates/update_manifest.dart';
import 'package:rogue/updates/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeService extends UpdateService {
  _FakeService({this.manifest, this.hash, this.failFetch = false})
    : super(manifestUrl: 'https://example.test/manifest.json');

  final UpdateManifest? manifest;
  final String? hash;
  final bool failFetch;
  int downloads = 0;

  @override
  Future<UpdateManifest> fetch() async {
    if (failFetch) throw const UpdateException('offline');
    return manifest!;
  }

  @override
  Future<File> download(
    ReleaseArtifact artifact, {
    required String fileName,
    void Function(int received, int total)? onProgress,
    Directory? into,
  }) async {
    downloads++;
    final dir = Directory.systemTemp.createTempSync('rogue-updates-test');
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(const [1, 2, 3]);
    onProgress?.call(3, 3);
    return file;
  }

  @override
  Future<String> sha256Of(File file) async => hash ?? 'deadbeef';
}

class _FakeInstaller extends UpdateInstaller {
  _FakeInstaller();
  bool staged = false;

  @override
  bool get canSelfInstall => true;

  @override
  String get actionLabel => 'Install update';

  @override
  Future<InstallOutcome> stage({
    required File artifact,
    required UpdateManifest manifest,
  }) async {
    staged = true;
    return InstallOutcome.staged;
  }
}

UpdateManifest _manifest(String version, {String windowsHash = 'abc123'}) =>
    UpdateManifest(
      version: AppVersion.parse(version),
      notes: 'Fixes and things.',
      windows: ReleaseArtifact(
        url: 'https://example.test/win.zip',
        sha256: windowsHash,
      ),
      android: ReleaseArtifact(
        url: 'https://example.test/app.apk',
        sha256: windowsHash,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppVersion', () {
    test('parses pubspec style versions', () {
      expect(AppVersion.parse('1.2.3').toString(), '1.2.3');
      expect(AppVersion.parse('1.2.3+14').toString(), '1.2.3+14');
      expect(AppVersion.parse('1.2').semver, '1.2.0');
      expect(AppVersion.parse('').semver, '0.0.0');
      expect(AppVersion.parse('garbage').semver, '0.0.0');
      expect(AppVersion.parse('1.2.3-beta+5').build, 5);
    });

    test('orders by release, then build number', () {
      expect(AppVersion.parse('1.2.3') > AppVersion.parse('1.2.2'), isTrue);
      expect(AppVersion.parse('1.2.3+4') > AppVersion.parse('1.2.3+3'), isTrue);
      expect(
        AppVersion.parse('1.2.3+3').sameReleaseAs(AppVersion.parse('1.2.3+9')),
        isTrue,
      );
      expect(AppVersion.parse('1.3.0') > AppVersion.parse('1.2.9+9'), isTrue);
    });
  });

  group('UpdateManifest', () {
    test('parses a published manifest', () {
      final manifest = UpdateManifest.tryParse({
        'version': '1.3.0',
        'build': 13,
        'minSupported': '1.1.0',
        'notes': '  Big fixes  ',
        'page': 'https://example.test/release',
        'windows': {
          'url': 'https://example.test/win.zip',
          'sha256': 'AA' * 32,
          'size': 123,
        },
        'android': {'url': 'https://example.test/app.apk', 'sha256': 'BB' * 32},
      });

      expect(manifest, isNotNull);
      expect(manifest!.version.toString(), '1.3.0+13');
      expect(manifest.notes, 'Big fixes');
      expect(manifest.minSupported?.semver, '1.1.0');
      expect(manifest.windows?.sha256, 'aa' * 32);
      expect(manifest.windows?.size, 123);
      expect(manifest.artifactFor(UpdateTarget.android)?.url, endsWith('.apk'));
    });

    test('decodes a body with a BOM, as served by release assets', () {
      final manifest = UpdateManifest.tryDecode(
        '\uFEFF{"version":"1.4.0","build":4,"windows":{"url":"https://e.test/w.zip","sha256":"FF"}}',
      );
      expect(manifest, isNotNull);
      expect(manifest!.version.toString(), '1.4.0+4');
      expect(manifest.windows?.sha256, 'ff');

      expect(UpdateManifest.tryDecode('not json'), isNull);
      expect(UpdateManifest.tryDecode('{"notes":"no version"}'), isNull);
    });

    test(
      'skips malformed artifacts and refuses a manifest without a version',
      () {
        final manifest = UpdateManifest.tryParse({
          'version': '2.0.0',
          'windows': {'url': 'https://example.test/win.zip'},
        });
        expect(manifest, isNotNull);
        expect(manifest!.windows, isNull);
        expect(manifest.android, isNull);

        expect(UpdateManifest.tryParse({'notes': 'no version'}), isNull);
        expect(UpdateManifest.tryParse('nope'), isNull);
      },
    );

    test('knows when an update is available or required', () {
      final manifest = _manifest('1.2.0');
      expect(manifest.isNewerThan(AppVersion.parse('1.1.9+9')), isTrue);
      expect(manifest.isNewerThan(AppVersion.parse('1.2.0')), isFalse);

      final floor = UpdateManifest.tryParse({
        'version': '2.0.0',
        'minSupported': '1.5.0',
      })!;
      expect(floor.requiresUpdateFrom(AppVersion.parse('1.4.0')), isTrue);
      expect(floor.requiresUpdateFrom(AppVersion.parse('1.5.0')), isFalse);
    });
  });

  group('UpdateController', () {
    test('reports an available update', () async {
      final controller = UpdateController(
        service: _FakeService(manifest: _manifest('1.2.0')),
        installer: _FakeInstaller(),
        currentVersion: AppVersion.parse('1.1.0+11'),
      );

      await controller.check();

      expect(controller.phase, UpdatePhase.available);
      expect(controller.manifest?.version.toString(), '1.2.0');
      expect(controller.lastChecked, isNotNull);
    });

    test('reports up to date when the manifest is not newer', () async {
      final controller = UpdateController(
        service: _FakeService(manifest: _manifest('1.1.0')),
        installer: _FakeInstaller(),
        currentVersion: AppVersion.parse('1.1.0+11'),
      );

      await controller.check();
      expect(controller.phase, UpdatePhase.upToDate);
    });

    test('honours a skipped version until something newer appears', () async {
      final service = _FakeService(manifest: _manifest('1.2.0'));
      final controller = UpdateController(
        service: service,
        installer: _FakeInstaller(),
        currentVersion: AppVersion.parse('1.1.0+11'),
      );

      await controller.check();
      await controller.skip();
      expect(controller.phase, UpdatePhase.skipped);

      await controller.check();
      expect(controller.phase, UpdatePhase.skipped);
    });

    test('surfaces a failed check without throwing', () async {
      final controller = UpdateController(
        service: _FakeService(failFetch: true),
        installer: _FakeInstaller(),
        currentVersion: AppVersion.parse('1.1.0'),
      );

      await controller.check();
      expect(controller.phase, UpdatePhase.error);
      expect(controller.error, contains('offline'));
    });

    test('verifies the download before staging it', () async {
      final installer = _FakeInstaller();
      final controller = UpdateController(
        service: _FakeService(manifest: _manifest('1.2.0'), hash: 'abc123'),
        installer: installer,
        currentVersion: AppVersion.parse('1.1.0'),
        target: UpdateTarget.windows,
      );

      await controller.check();
      await controller.install();

      expect(controller.phase, UpdatePhase.staged);
      expect(installer.staged, isTrue);
    });

    test('refuses a download whose hash does not match', () async {
      final installer = _FakeInstaller();
      final controller = UpdateController(
        service: _FakeService(manifest: _manifest('1.2.0'), hash: 'incorrect'),
        installer: installer,
        currentVersion: AppVersion.parse('1.1.0'),
        target: UpdateTarget.windows,
      );

      await controller.check();
      await controller.install();

      expect(controller.phase, UpdatePhase.error);
      expect(controller.error, contains('checksum'));
      expect(installer.staged, isFalse);
    });

    test('labels unconfigured builds instead of calling home', () async {
      final controller = UpdateController(
        service: UpdateService(manifestUrl: ''),
        installer: _FakeInstaller(),
      );

      await controller.start();
      expect(controller.phase, UpdatePhase.notConfigured);
      expect(controller.isConfigured, isFalse);
    });
  });
}
