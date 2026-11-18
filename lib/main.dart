import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/app_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.init();
  AppLog.installHandlers();
  MediaKit.ensureInitialized();
  runApp(const RogueApp());
}
