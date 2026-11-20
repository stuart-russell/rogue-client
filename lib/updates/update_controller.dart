import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_log.dart';
import 'app_version.dart';
import 'update_installer.dart';
import 'update_manifest.dart';
import 'update_service.dart';

enum UpdatePhase {
  /// No manifest URL compiled in (development builds).
  notConfigured,
  idle,
  checking,
  upToDate,
  available,
  skipped,

  /// Downloading and verifying the artifact.
  downloading,

  /// Staged on disk; a restart finishes the update.
  staged,

  /// Handed to the Android package installer.
  handedOff,

  /// Artifact saved; the copy cannot update itself.
  manual,
  error,
}

/// Checks for updates, verifies downloads and applies them.
class UpdateController extends ChangeNotifier {
  UpdateController({
    UpdateService? service,
    UpdateInstaller? installer,
    AppVersion? currentVersion,
    UpdateTarget? target,
  }) : _service = service ?? UpdateService(),
       _installer = installer ?? installerForCurrentPlatform(),
       _target = target ?? currentUpdateTarget,
       currentVersion = currentVersion ?? AppVersion.running;

  static const Duration _staleAfter = Duration(hours: 6);
  static const _kLastCheck = 'update.lastCheck';
  static const _kSkipped = 'update.skippedVersion';

  final UpdateService _service;
  final UpdateInstaller _installer;
  final UpdateTarget? _target;
  final AppVersion currentVersion;

  UpdateManifest? _manifest;
  UpdatePhase _phase = UpdatePhase.idle;
  String? _error;
  double? _progress;
  DateTime? _lastChecked;
  String? _skippedVersion;
  bool _started = false;

  UpdateManifest? get manifest => _manifest;
  UpdatePhase get phase => _phase;
  String? get error => _error;
  double? get progress => _progress;
  DateTime? get lastChecked => _lastChecked;
  bool get isConfigured => _service.isConfigured;
  bool get canSelfInstall => _installer.canSelfInstall;
  String get actionLabel => _installer.actionLabel;
  AppVersion get version => currentVersion;
  String? get skippedVersion => _skippedVersion;
  bool get busy =>
      _phase == UpdatePhase.checking || _phase == UpdatePhase.downloading;

  bool get hasUpdate =>
      _phase == UpdatePhase.available ||
      _phase == UpdatePhase.skipped ||
      _phase == UpdatePhase.staged ||
      _phase == UpdatePhase.handedOff;

  /// Loads persisted state and, when the channel is configured, checks quietly.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!_service.isConfigured) {
      _phase = UpdatePhase.notConfigured;
      notifyListeners();
      return;
    }
    await _restorePreferences();
    final last = _lastChecked;
    final due = last == null || DateTime.now().difference(last) > _staleAfter;
    if (due) {
      await check(silent: true);
    } else {
      _phase = UpdatePhase.upToDate;
      notifyListeners();
    }
  }

  Future<void> _restorePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLastCheck);
      if (raw != null) _lastChecked = DateTime.tryParse(raw);
      _skippedVersion = prefs.getString(_kSkipped);
    } catch (_) {
      // Update metadata is best-effort.
    }
  }

  Future<void> check({bool silent = false}) async {
    if (busy) return;
    _error = null;
    _phase = UpdatePhase.checking;
    notifyListeners();

    try {
      final manifest = await _service.fetch();
      _manifest = manifest;
      _lastChecked = DateTime.now();
      unawaited(_persistLastCheck(_lastChecked!));

      if (manifest.requiresUpdateFrom(currentVersion)) {
        _phase = UpdatePhase.available;
      } else if (!manifest.isNewerThan(currentVersion)) {
        _phase = UpdatePhase.upToDate;
      } else if (manifest.version.toString() == _skippedVersion) {
        _phase = UpdatePhase.skipped;
      } else {
        _phase = UpdatePhase.available;
      }
      AppLog.write('update check: ${manifest.version} (${_phase.name})');
    } catch (error) {
      _error = _messageFor(error);
      _phase = UpdatePhase.error;
      if (!silent) AppLog.write('update check failed: $_error');
    } finally {
      notifyListeners();
    }
  }

  /// Downloads, verifies and stages the update.
  Future<void> install() async {
    final manifest = _manifest;
    if (manifest == null || busy) return;

    final target = _target;
    final artifact = target == null ? null : manifest.artifactFor(target);
    if (target == null || artifact == null) {
      _error = 'No build is published for this platform yet.';
      _phase = UpdatePhase.error;
      notifyListeners();
      return;
    }

    _error = null;
    _progress = 0;
    _phase = UpdatePhase.downloading;
    notifyListeners();

    File? artifactFile;
    try {
      final name =
          'rogue-${manifest.version}${target == UpdateTarget.windows ? '.zip' : '.apk'}';
      artifactFile = await _service.download(
        artifact,
        fileName: name,
        onProgress: (received, total) {
          if (total <= 0) return;
          _progress = (received / total).clamp(0.0, 1.0);
          notifyListeners();
        },
      );

      final actual = await _service.sha256Of(artifactFile);
      if (actual.toLowerCase() != artifact.sha256.toLowerCase()) {
        await artifactFile.delete();
        throw const UpdateException(
          'The download was incomplete or damaged — the checksum did not match. Try again.',
        );
      }

      final outcome = await _installer.stage(
        artifact: artifactFile,
        manifest: manifest,
      );
      _phase = switch (outcome) {
        InstallOutcome.staged => UpdatePhase.staged,
        InstallOutcome.handedOff => UpdatePhase.handedOff,
        InstallOutcome.manual => UpdatePhase.manual,
      };
      AppLog.write('update staged: ${manifest.version} (${_phase.name})');
    } catch (error) {
      _error = _messageFor(error);
      _phase = UpdatePhase.error;
      AppLog.write('update install failed: $_error');
    } finally {
      _progress = null;
      notifyListeners();
    }
  }

  /// Windows: relaunch into the staged build.
  Future<void> restart() => _installer.restart();

  Future<void> skip() async {
    final manifest = _manifest;
    if (manifest == null) return;
    _skippedVersion = manifest.version.toString();
    _phase = UpdatePhase.skipped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSkipped, _skippedVersion!);
    } catch (_) {
      // Ignore: skipping still works for this session.
    }
  }

  Future<void> _persistLastCheck(DateTime when) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastCheck, when.toIso8601String());
    } catch (_) {
      // Ignore.
    }
  }

  String _messageFor(Object error) {
    if (error is UpdateException) return error.message;
    if (error is SocketException || error is TimeoutException) {
      return 'Could not reach the update server. Check your connection and try again.';
    }
    return 'Update failed: $error';
  }
}
