import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLog.write('nav push ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLog.write('nav pop ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppLog.write(
      'nav replace ${oldRoute?.settings.name} -> ${newRoute?.settings.name}',
    );
  }
}

/// Minimal append-only log so a crash leaves a trail of what the app was doing.
///
/// Writes synchronously and swallows every error: logging must never be the
/// reason the app fails. The file is capped at ~1 MB and rotated once.
class AppLog {
  AppLog._();

  static File? _file;
  static bool _ready = false;

  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final logs = Directory('${dir.path}${Platform.pathSeparator}logs');
      if (!await logs.exists()) await logs.create(recursive: true);
      _file = File('${logs.path}${Platform.pathSeparator}app.log');
      if (await _file!.exists() && await _file!.length() > 1024 * 1024) {
        final rotated = File('${_file!.path}.1');
        if (await rotated.exists()) await rotated.delete();
        await _file!.rename(rotated.path);
      }
      _ready = true;
      write(
        'session started (${Platform.operatingSystem} ${Platform.operatingSystemVersion})',
      );
    } catch (_) {
      _ready = false;
    }
  }

  static String get path => _file?.path ?? '(unavailable)';

  static void write(String message) {
    if (!_ready) return;
    try {
      final stamp = DateTime.now().toIso8601String();
      _file!.writeAsStringSync(
        '$stamp  $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // ignore
    }
  }

  /// Installs Dart-level handlers so ordinary exceptions land in the log too.
  static void installHandlers() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      write('FlutterError: ${details.exceptionAsString()}');
      final context = details.context;
      if (context != null) write('  context: $context');
      final stack = details.stack;
      if (stack != null) {
        write(stack.toString().split('\n').take(8).join('\n'));
      }
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      write('Uncaught: $error');
      write(stack.toString().split('\n').take(8).join('\n'));
      return true;
    };
  }
}
