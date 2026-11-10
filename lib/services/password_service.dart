import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

Future<String> _derive((String, String, int) request) async {
  final key = await Pbkdf2(
          macAlgorithm: Hmac.sha256(), iterations: request.$3, bits: 256)
      .deriveKey(
          secretKey: SecretKey(utf8.encode(request.$1)),
          nonce: base64Url.decode(request.$2));
  return base64UrlEncode(await key.extractBytes());
}

class PasswordService {
  static const iterations = 600000;
  String randomToken([int bytes = 32]) {
    final random = Random.secure();
    return base64UrlEncode(
        List<int>.generate(bytes, (_) => random.nextInt(256)));
  }

  Future<String> derive(String password, String salt,
      [int rounds = iterations]) async {
    return compute(_derive, (password, salt, rounds));
  }

  Future<bool> verify(String password, Map<String, Object?> row) async {
    final actual = base64Url.decode(await derive(
        password, row['senha_salt'] as String, row['senha_iteracoes'] as int));
    final expected = base64Url.decode(row['senha_hash'] as String);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }
}
