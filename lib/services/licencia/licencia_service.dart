import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../data/repositories/config_repository.dart';
import '../../utils/app_exception.dart';
import 'licencia_config.dart';
import 'token_licencia.dart';

/// Activación (única consulta a internet) y verificación local de la licencia.
class LicenciaService {
  final ConfigRepository _config;
  final http.Client _http;
  final String _urlApi;
  final String _clavePublica;
  final Future<String> Function()? _idDispositivoPrueba;

  LicenciaService(
    this._config, {
    http.Client? cliente,
    String? urlApi,
    String? clavePublica,
    Future<String> Function()? idDispositivo,
  })  : _http = cliente ?? http.Client(),
        _urlApi = urlApi ?? LicenciaConfig.urlApi,
        _clavePublica = clavePublica ?? LicenciaConfig.clavePublica,
        _idDispositivoPrueba = idDispositivo;

  static const _canal = MethodChannel('bo.ventapollos/dispositivo');
  static const _kToken = 'licencia_token';
  static const _kClaveHash = 'licencia_clave_hash';
  static const _kIdLocal = 'dispositivo_id_local';

  String? _dispositivoCache;

  /// SHA-256 del identificador del celular. En Android se usa ANDROID_ID,
  /// que sobrevive a reinstalar la app o borrar sus datos.
  Future<String> dispositivo() async {
    if (_dispositivoCache != null) return _dispositivoCache!;
    final id = await (_idDispositivoPrueba?.call() ?? _idNativo());
    return _dispositivoCache = sha256
        .convert(utf8.encode('${LicenciaConfig.producto}:$id'))
        .toString();
  }

  Future<String> _idNativo() async {
    if (Platform.isAndroid) {
      final id = await _canal.invokeMethod<String>('androidId');
      if (id != null && id.isNotEmpty) return id;
    }
    // Otras plataformas: identificador aleatorio guardado en la app.
    final guardado = await _config.leer(_kIdLocal);
    if (guardado != null) return guardado;
    final r = Random.secure();
    final nuevo = List.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _config.escribir({_kIdLocal: nuevo});
    return nuevo;
  }

  Future<String?> _modelo() async {
    try {
      return Platform.isAndroid
          ? await _canal.invokeMethod<String>('modelo')
          : Platform.operatingSystem;
    } catch (_) {
      return null;
    }
  }

  /// Licencia guardada y válida para ESTE celular, o null.
  /// Si existe pero venció, se devuelve igual para mostrar el aviso.
  Future<TokenLicencia?> licenciaGuardada() async {
    final token = await _config.leer(_kToken);
    if (token == null) return null;
    final t = await TokenLicencia.verificar(token, _clavePublica);
    if (t == null ||
        t.producto != LicenciaConfig.producto ||
        t.dispositivo != await dispositivo()) {
      return null; // alterado, de otra app o copiado de otro celular
    }
    return t;
  }

  /// Envía la clave a la API (única vez que se usa internet).
  Future<TokenLicencia> activar(String clave) async {
    if (_urlApi.isEmpty) {
      throw AppException(
          'Esta versión no tiene configurado el servidor de licencias.');
    }
    final disp = await dispositivo();
    final http.Response r;
    try {
      r = await _http
          .post(
            Uri.parse('$_urlApi/v1/activar'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'clave': clave.trim(),
              'dispositivo': disp,
              'producto': LicenciaConfig.producto,
              'modelo': await _modelo(),
              'version_app': LicenciaConfig.versionApp,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AppException('El servidor no respondió. Revise su conexión.');
    } on SocketException {
      throw AppException(
          'Sin conexión a internet. Se necesita solo para activar.');
    } on http.ClientException {
      throw AppException('No se pudo contactar al servidor de licencias.');
    }

    Map<String, dynamic> cuerpo;
    try {
      cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw AppException(
          'Respuesta inesperada del servidor (${r.statusCode}).');
    }
    if (cuerpo['ok'] != true) {
      throw AppException(
          cuerpo['mensaje'] as String? ?? 'No se pudo activar la licencia');
    }

    final token = cuerpo['token'] as String;
    final t = await TokenLicencia.verificar(token, _clavePublica);
    if (t == null || t.dispositivo != disp) {
      throw AppException('La respuesta del servidor no es válida.');
    }
    await _config.escribir({_kToken: token, _kClaveHash: t.claveHash});
    return t;
  }
}
