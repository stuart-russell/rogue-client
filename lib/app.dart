import 'package:flutter/material.dart';

import 'core/app_log.dart';
import 'state/app_model.dart';
import 'theme.dart';
import 'ui/focus_revealer.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';
import 'ui/responsive.dart';
import 'ui/tv_scale.dart';

class RogueApp extends StatefulWidget {
  const RogueApp({super.key});

  @override
  State<RogueApp> createState() => _RogueAppState();
}

class _RogueAppState extends State<RogueApp> {
  final AppModel _model = AppModel();
  final LoggingNavigatorObserver _observer = LoggingNavigatorObserver();

  late Palette _palette = _model.preferences.palette;
  ThemeData? _theme;

  @override
  void initState() {
    super.initState();
    AppColors.current = _palette;
    _model.addListener(_onModelChanged);
    _model.init();
  }

  void _onModelChanged() {
    final palette = _model.preferences.palette;
    if (palette.id == _palette.id) return;
    AppColors.current = palette;
    setState(() {
      _palette = palette;
      _theme = null;
    });
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.current = _palette;
    return AppScope(
      model: _model,
      child: MaterialApp(
        title: 'Rogue',
        debugShowCheckedModeBanner: false,
        theme: _theme ??= buildAppTheme(_palette),
        navigatorObservers: [_observer],
        builder: (context, child) {
          final content = FocusRevealer(
            child: child ?? const SizedBox.shrink(),
          );
          return isTv(context) ? TvScale(child: content) : content;
        },
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);

    Widget child;
    if (!model.initialised) {
      child = const _Splash(key: ValueKey('splash'));
    } else if (model.session.signedIn) {
      child = const HomeShell(key: ValueKey('home'));
    } else {
      child = const LoginScreen(key: ValueKey('login'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.accent,
              ),
            ),
            SizedBox(height: 22),
            Text(
              'ROGUE',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
