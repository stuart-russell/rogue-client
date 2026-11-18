import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Random salt for the parental PIN.
String newPinSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

/// Salted SHA-256. The PIN itself is never stored.
String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();
