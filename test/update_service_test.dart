import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/updates/update_service.dart';

/// Exercises the real dio plumbing against a local server that mimics a GitHub
/// release asset: an octet-stream body, a JSON manifest and a binary artifact.
void main() {
  late HttpServer server;
  late Directory tempDir;

  final artifactBytes = utf8.encode('pretend-apk-contents');
  final artifactHash = sha256.convert(artifactBytes).toString();

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('rogue-update-service');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/manifest.json':
          response.headers.contentType = ContentType.binary;
          response.add(
            utf8.encode(
              jsonEncode({
                'version': '2.0.0',
                'build': 20,
                'notes': 'From a release asset',
                'windows': {
                  'url': 'http://127.0.0.1:${server.port}/build.bin',
                  'sha256': artifactHash,
                  'size': artifactBytes.length,
                },
              }),
            ),
          );
        case '/build.bin':
          response.add(artifactBytes);
        default:
          response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tempDir.deleteSync(recursive: true);
  });

  test('reads an octet-stream manifest and downloads a verified artifact', () async {
    final service = UpdateService(
      manifestUrl: 'http://127.0.0.1:${server.port}/manifest.json',
    );

    final manifest = await service.fetch();
    expect(manifest.version.toString(), '2.0.0+20');
    expect(manifest.notes, 'From a release asset');

    final artifact = manifest.windows!;
    var lastReceived = 0;
    final file = await service.download(
      artifact,
      fileName: 'build.bin',
      into: tempDir,
      onProgress: (received, total) => lastReceived = received,
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), artifactBytes.length);
    expect(lastReceived, artifactBytes.length);
    expect(await service.sha256Of(file), artifactHash);
  });

  test('reports a body that is not a manifest', () async {
    final service = UpdateService(manifestUrl: 'http://127.0.0.1:${server.port}/missing.json');
    await expectLater(service.fetch(), throwsA(isA<Exception>()));
  });
}
