import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Contenido del token firmado por la API de licencias.
class TokenLicencia {
  final String producto;
  final int licenciaId;
  final String tipo; // beta | completa
  final String dispositivo; // SHA-256 del identificador del celular
  final String claveHash; // SHA-256 de la clave
  final DateTime emitido;
  final DateTime? expira; // null = perpetua

  const TokenLicencia({
    required this.producto,
    required this.licenciaId,
    required this.tipo,
    required this.dispositivo,
    required this.claveHash,
    required this.emitido,
    this.expira,
  });

  bool get esBeta => tipo == 'beta';
  bool vigente(DateTime ahora) => expira == null || ahora.isBefore(expira!);

  /// Acepta número o texto (versiones anteriores de la API enviaban texto).
  static int _entero(Object? v) => v is int ? v : int.parse('$v');

  static DateTime _fecha(Object? seg) =>
      DateTime.fromMillisecondsSinceEpoch(_entero(seg) * 1000, isUtc: true);

  factory TokenLicencia.fromJson(Map<String, dynamic> j) => TokenLicencia(
        producto: j['prod'] as String,
        licenciaId: _entero(j['lic']),
        tipo: j['tipo'] as String,
        dispositivo: j['disp'] as String,
        claveHash: j['clave'] as String,
        emitido: _fecha(j['iat']),
        expira: j['exp'] == null ? null : _fecha(j['exp']),
      );

  /// Verifica la firma Ed25519 sin internet. Devuelve null si el token fue
  /// alterado, está mal formado o no lo firmó el servidor.
  static Future<TokenLicencia?> verificar(
      String token, String clavePublicaBase64) async {
    try {
      final partes = token.split('.');
      if (partes.length != 2) return null;
      final ok = await Ed25519().verify(
        utf8.encode(partes[0]),
        signature: Signature(
          _deBase64Url(partes[1]),
          publicKey: SimplePublicKey(
            base64Decode(clavePublicaBase64),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!ok) return null;
      final json = jsonDecode(utf8.decode(_deBase64Url(partes[0])));
      if (json is! Map<String, dynamic> || json['v'] != 1) return null;
      return TokenLicencia.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static List<int> _deBase64Url(String s) =>
      base64Url.decode(s.padRight(s.length + (4 - s.length % 4) % 4, '='));
}
