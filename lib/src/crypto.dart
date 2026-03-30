import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Compute HMAC-SHA256 and return the result as a lowercase hex string.
String hmacSHA256(String secret, String message) {
  final key = utf8.encode(secret);
  final msg = utf8.encode(message);
  final hmac = Hmac(sha256, key);
  return hmac.convert(msg).toString();
}

/// Generate a short random alphanumeric ID.
String uid() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random.secure();
  return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
}
