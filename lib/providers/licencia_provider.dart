import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/licencia/licencia_service.dart';
import '../services/licencia/token_licencia.dart';

enum EstadoLicencia { cargando, sinLicencia, expirada, activa }

class LicenciaProvider extends ChangeNotifier {
  final LicenciaService _servicio;
  final DateTime Function() _ahora;
  LicenciaProvider(this._servicio, {DateTime Function()? ahora})
      : _ahora = ahora ?? DateTime.now;

  EstadoLicencia estado = EstadoLicencia.cargando;
  TokenLicencia? licencia;
  Timer? _revision;

  bool get activa => estado == EstadoLicencia.activa;

  /// Días que le quedan a una beta (null si es perpetua).
  int? get diasRestantes {
    final exp = licencia?.expira;
    if (exp == null) return null;
    return (exp.difference(_ahora()).inHours / 24).ceil().clamp(0, 9999);
  }

  Future<void> cargar() async {
    licencia = await _servicio.licenciaGuardada();
    _evaluar();
    // Si la app queda abierta, la beta debe cerrarse al vencer.
    _revision ??=
        Timer.periodic(const Duration(minutes: 15), (_) => _evaluar());
  }

  void _evaluar() {
    final nuevo = licencia == null
        ? EstadoLicencia.sinLicencia
        : licencia!.vigente(_ahora())
            ? EstadoLicencia.activa
            : EstadoLicencia.expirada;
    if (nuevo != estado) {
      estado = nuevo;
      notifyListeners();
    }
  }

  /// Identificador corto del celular, útil para soporte (liberar dispositivo).
  Future<String> idEquipo() async =>
      (await _servicio.dispositivo()).substring(0, 8).toUpperCase();

  Future<void> activar(String clave) async {
    licencia = await _servicio.activar(clave);
    _evaluar();
    notifyListeners();
  }

  @override
  void dispose() {
    _revision?.cancel();
    super.dispose();
  }
}
