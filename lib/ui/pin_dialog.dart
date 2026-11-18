import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Asks for a 4–8 digit PIN. Returns null when cancelled.
///
/// With [confirm] a second field validates the entry (used when setting a PIN).
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  String? message,
  bool confirm = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _PinDialog(title: title, message: message, confirm: confirm),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, required this.confirm, this.message});

  final String title;
  final String? message;
  final bool confirm;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pin.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _error = 'Use 4–8 digits.');
      return;
    }
    if (widget.confirm && _confirm.text.trim() != pin) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    Navigator.pop(context, pin);
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceHigh,
    labelStyle: TextStyle(color: AppColors.textMuted),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.accent, width: 1.3),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundElevated,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onSubmitted: (_) => widget.confirm ? null : _submit(),
            decoration: _decoration('PIN'),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              onSubmitted: (_) => _submit(),
              decoration: _decoration('Confirm PIN'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
