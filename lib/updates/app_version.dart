/// Semantic-ish app version (`major.minor.patch`, optional `+build`).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.build = 0]);

  final int major;
  final int minor;
  final int patch;

  /// Monotonic build number, the `+N` part of a pubspec version.
  final int build;

  /// Injected by the build scripts / CI from `pubspec.yaml`.
  static const String raw = String.fromEnvironment(
    'ROGUE_VERSION',
    defaultValue: '0.3.1+7',
  );

  static AppVersion get running => AppVersion.parse(raw);

  factory AppVersion.parse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return const AppVersion(0, 0, 0);

    final plus = text.indexOf('+');
    final core = plus == -1 ? text : text.substring(0, plus);
    final buildText = plus == -1 ? '' : text.substring(plus + 1);
    final parts = core.split('.');

    int at(int index) {
      if (index >= parts.length) return 0;
      final digits = RegExp(r'^\d+').firstMatch(parts[index].trim())?.group(0);
      return int.tryParse(digits ?? '') ?? 0;
    }

    final build = int.tryParse(RegExp(r'^\d+').firstMatch(buildText)?.group(0) ?? '') ?? 0;
    return AppVersion(at(0), at(1), at(2), build);
  }

  /// `1.2.3`, without the build number.
  String get semver => '$major.$minor.$patch';

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    if (patch != other.patch) return patch - other.patch;
    return build - other.build;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;

  /// Equal ignoring the build number, which is what a "same release" check wants.
  bool sameReleaseAs(AppVersion other) =>
      major == other.major && minor == other.minor && patch == other.patch;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => build > 0 ? '$semver+$build' : semver;
}
