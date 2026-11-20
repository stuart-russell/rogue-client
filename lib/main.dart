import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/app_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android TV can report touch mode even while a D-pad is driving focus;
  // without this, Material buttons/switches never draw their focus state.
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  await AppLog.init();
  AppLog.installHandlers();
  MediaKit.ensureInitialized();
  runApp(const RogueApp());
}
