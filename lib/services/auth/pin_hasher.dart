import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de PIN con PBKDF2-HMAC-SHA256 y sal aleatoria por usuario.
/// Nunca se guarda el PIN en texto plano.
class PinHasher {
  static const iteraciones = 20000;
  static final _formato = RegExp(r'^\d{4,8}$');

  static String? validar(String pin) =>
      _formato.hasMatch(pin) ? null : 'El PIN debe tener de 4 a 8 dígitos';

  static String nuevaSal() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Se ejecuta en otro isolate para no congelar la interfaz.
  static Future<String> hash(String pin, String sal, int iteraciones) =>
      Isolate.run(() => _pbkdf2(pin, sal, iteraciones));

  static Future<bool> verificar(
      String pin, String sal, int iteraciones, String esperado) async {
    final calculado = await hash(pin, sal, iteraciones);
    return _igualesTiempoConstante(calculado, esperado);
  }

  static String _pbkdf2(String pin, String sal, int iteraciones) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = hmac.convert([...base64Decode(sal), 0, 0, 0, 1]).bytes;
    final resultado = Uint8List.fromList(u);
    for (var i = 1; i < iteraciones; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < resultado.length; j++) {
        resultado[j] ^= u[j];
      }
    }
    return base64Encode(resultado);
  }

  static bool _igualesTiempoConstante(String a, String b) {
    if (a.length != b.length) return false;
    var diferencia = 0;
    for (var i = 0; i < a.length; i++) {
      diferencia |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diferencia == 0;
  }
}
