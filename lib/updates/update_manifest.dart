import 'dart:convert';
import 'dart:io' show Platform;

import 'app_version.dart';

/// Which build an artifact belongs to.
enum UpdateTarget { windows, android }

UpdateTarget? get currentUpdateTarget {
  if (Platform.isWindows) return UpdateTarget.windows;
  if (Platform.isAndroid) return UpdateTarget.android;
  return null;
}

/// A downloadable build plus the hash the app verifies before touching it.
class ReleaseArtifact {
  const ReleaseArtifact({required this.url, required this.sha256, this.size});

  final String url;
  final String sha256;
  final int? size;

  static ReleaseArtifact? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url']?.toString().trim() ?? '';
    final hash = raw['sha256']?.toString().trim().toLowerCase() ?? '';
    if (url.isEmpty || hash.isEmpty) return null;
    final size = raw['size'];
    return ReleaseArtifact(
      url: url,
      sha256: hash,
      size: size is num ? size.toInt() : int.tryParse(size?.toString() ?? ''),
    );
  }
}

/// The JSON document published with each GitHub release.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.notes,
    this.minSupported,
    this.pageUrl,
    this.windows,
    this.android,
  });

  final AppVersion version;
  final String notes;

  /// Clients older than this are told to update instead of being offered it.
  final AppVersion? minSupported;

  /// Human-facing release page, opened when the app cannot self-install.
  final String? pageUrl;
  final ReleaseArtifact? windows;
  final ReleaseArtifact? android;

  ReleaseArtifact? artifactFor(UpdateTarget target) => switch (target) {
    UpdateTarget.windows => windows,
    UpdateTarget.android => android,
  };

  bool isNewerThan(AppVersion other) => version > other;

  bool requiresUpdateFrom(AppVersion other) {
    final floor = minSupported;
    return floor != null && other < floor;
  }

  /// Decodes a manifest body, tolerating a UTF-8 BOM (PowerShell loves them).
  static UpdateManifest? tryDecode(String body) {
    final text = body.startsWith('\uFEFF') ? body.substring(1) : body;
    try {
      return tryParse(jsonDecode(text.trim()));
    } on FormatException {
      return null;
    }
  }

  /// Tolerant parser: unknown fields are ignored, malformed artifacts skipped.
  static UpdateManifest? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final version = AppVersion.parse(raw['version']?.toString() ?? '');
    if (version.major == 0 && version.minor == 0 && version.patch == 0) {
      return null;
    }

    final build = raw['build'];
    final buildNumber = build is num
        ? build.toInt()
        : int.tryParse(build?.toString() ?? '');
    final resolved = buildNumber == null
        ? version
        : AppVersion(version.major, version.minor, version.patch, buildNumber);

    final floor = raw['minSupported']?.toString().trim();

    return UpdateManifest(
      version: resolved,
      notes: raw['notes']?.toString().trim() ?? '',
      minSupported: floor == null || floor.isEmpty
          ? null
          : AppVersion.parse(floor),
      pageUrl: (raw['page'] ?? raw['pageUrl'])?.toString().trim(),
      windows: ReleaseArtifact.tryParse(raw['windows']),
      android: ReleaseArtifact.tryParse(raw['android']),
    );
  }
}
