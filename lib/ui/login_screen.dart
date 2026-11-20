import 'package:flutter/material.dart';

import '../data/portals.dart';
import '../state/app_model.dart';
import '../theme.dart';
import 'widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  bool _prefilled = false;
  bool _customServer = false;
  int? _portalIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;

    final model = AppScope.read(context);
    final session = model.session;
    const buildDefaultServer = String.fromEnvironment('ROGUE_DEFAULT_SERVER');
    final saved = session.server.isNotEmpty
        ? session.server
        : buildDefaultServer;

    _server.text = saved;
    _username.text = session.username;

    final presets = model.portals;
    if (presets.isEmpty) {
      _customServer = true;
      return;
    }

    var index = presets.indexWhere((preset) => samePortal(preset.url, saved));
    if (index >= 0) {
      _portalIndex = index;
      _customServer = false;
      _server.text = presets[index].url;
    } else if (saved.isEmpty) {
      _portalIndex = 0;
      _customServer = false;
      _server.text = presets.first.url;
    } else {
      _portalIndex = 0;
      _customServer = true;
    }
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    if (_server.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _password.text.isEmpty) {
      _snack('Server, username and password are all required.');
      return;
    }

    setState(() => _submitting = true);
    final model = AppScope.read(context);
    final ok = await model.login(
      serverUrl: _server.text.trim(),
      user: _username.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      _snack(model.session.error ?? 'Login failed.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), width: 460));
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Center(child: AppMark(size: 24)),
                      const SizedBox(height: 26),
                      _form(model.session.error),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverPicker(List<PortalPreset> presets) {
    if (presets.isEmpty) {
      return TextField(
        controller: _server,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: fieldDecoration(
          label: 'Server URL',
          hint: 'http://panel.example.com:8080',
          prefixIcon: const Icon(Icons.dns_outlined, size: 19),
        ),
      );
    }

    final selectedUrl = _server.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: const ValueKey('portal-picker'),
          initialValue: _customServer ? -1 : (_portalIndex ?? 0),
          isExpanded: true,
          dropdownColor: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.text,
            fontWeight: FontWeight.w500,
          ),
          decoration: fieldDecoration(
            label: 'Portal',
            prefixIcon: const Icon(Icons.dns_outlined, size: 19),
          ),
          items: [
            for (var i = 0; i < presets.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(presets[i].name, overflow: TextOverflow.ellipsis),
              ),
            DropdownMenuItem<int>(
              value: -1,
              child: Text(
                'Custom server…',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              if (value < 0) {
                _customServer = true;
              } else {
                _customServer = false;
                _portalIndex = value;
                _server.text = presets[value].url;
              }
            });
          },
        ),
        if (!_customServer) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.link_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedUrl.isEmpty
                      ? presets[(_portalIndex ?? 0)].url
                      : selectedUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 10),
          TextField(
            controller: _server,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: fieldDecoration(
              label: 'Server URL',
              hint: 'http://panel.example.com:8080',
              prefixIcon: const Icon(Icons.dns_outlined, size: 19),
            ),
          ),
        ],
      ],
    );
  }

  Widget _form(String? error) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
      decoration: glassPanel(
        color: AppColors.backgroundElevated.withValues(alpha: 0.92),
        radius: 18,
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign in',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 22),
            _serverPicker(AppScope.read(context).portals),
            const SizedBox(height: 14),
            TextField(
              controller: _username,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              decoration: fieldDecoration(
                label: 'Username',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
              ),
            ),
            const SizedBox(height: 14),
            TvTextInput(
              child: TextField(
                controller: _password,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: tvSecureKeyboardType(context),
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: fieldDecoration(
                  label: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 17,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.text,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0C12), Color(0xFF08090D), Color(0xFF0C0A10)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: _glow(520, AppColors.accent.withValues(alpha: 0.16)),
          ),
          Positioned(
            bottom: -220,
            right: -100,
            child: _glow(560, AppColors.blue.withValues(alpha: 0.11)),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}
