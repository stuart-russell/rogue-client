import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'update_manifest.dart';

/// Fetches the manifest and downloads artifacts. Stateless and injectable so
/// the controller can be tested without touching the network.
class UpdateService {
  UpdateService({Dio? dio, String? manifestUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(minutes: 2),
                headers: {'Accept': 'application/json'},
              ),
            ),
        manifestUrl = manifestUrl ?? defaultManifestUrl;

  final Dio _dio;
  final String manifestUrl;

  /// Published as a release asset, so this URL always resolves to the newest
  /// release without using the GitHub API (no rate limits, no token).
  static const String defaultManifestUrl = String.fromEnvironment(
    'ROGUE_UPDATE_MANIFEST',
    defaultValue: '',
  );

  bool get isConfigured => manifestUrl.trim().isNotEmpty;

  Future<UpdateManifest> fetch() async {
    if (!isConfigured) {
      throw const UpdateException('This build has no update channel configured.');
    }
    // Release assets are served as octet-stream, so ask for text and decode it
    // ourselves rather than relying on the content type.
    final response = await _dio.get<dynamic>(
      manifestUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    final manifest = body is String ? UpdateManifest.tryDecode(body) : UpdateManifest.tryParse(body);
    if (manifest == null) {
      throw const UpdateException('The update manifest could not be understood.');
    }
    return manifest;
  }

  Future<File> download(
    ReleaseArtifact artifact, {
    required String fileName,
    void Function(int received, int total)? onProgress,
    Directory? into,
  }) async {
    final dir = into ?? await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) await file.delete();
    await _dio.download(
      artifact.url,
      file.path,
      onReceiveProgress: onProgress,
      deleteOnError: true,
    );
    return file;
  }

  Future<String> sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
