import 'package:flutter/foundation.dart';

import '../data/repositories/usuario_repository.dart';
import '../models/usuario.dart';
import '../utils/app_exception.dart';

class AuthProvider extends ChangeNotifier {
  final UsuarioRepository _repo;
  AuthProvider(this._repo);

  static const intentosMaximos = 5;
  static const duracionBloqueo = Duration(seconds: 60);

  bool cargando = true;
  List<Usuario> usuarios = [];
  Usuario? actual;

  final _fallos = <int, int>{};
  final _bloqueadoHasta = <int, DateTime>{};

  bool get esAdmin => actual?.esAdmin ?? false;
  List<Usuario> get activos => usuarios.where((u) => u.activo).toList();

  /// Primer uso: aún no existe ningún usuario.
  bool get requiereConfiguracion => !cargando && usuarios.isEmpty;

  Future<void> cargar() async {
    usuarios = await _repo.todos();
    cargando = false;
    notifyListeners();
  }

  Future<void> crearAdministradorInicial(String nombre, String pin) async {
    if (await _repo.contar() > 0) {
      throw AppException('El administrador inicial ya fue creado');
    }
    actual = await _repo.crear(nombre: nombre, rol: Rol.admin, pin: pin);
    await cargar();
  }

  Duration? bloqueoRestante(Usuario u) {
    final hasta = _bloqueadoHasta[u.id];
    if (hasta == null) return null;
    final restante = hasta.difference(DateTime.now());
    return restante.isNegative ? null : restante;
  }

  /// Devuelve null si el ingreso fue correcto, o el mensaje de error.
  Future<String?> iniciarSesion(Usuario u, String pin) async {
    final bloqueo = bloqueoRestante(u);
    if (bloqueo != null) {
      return 'Demasiados intentos. Espere ${bloqueo.inSeconds + 1} s';
    }
    final verificado = await _repo.verificar(u.id, pin);
    if (verificado == null) {
      final fallos = (_fallos[u.id] ?? 0) + 1;
      if (fallos >= intentosMaximos) {
        _fallos.remove(u.id);
        _bloqueadoHasta[u.id] = DateTime.now().add(duracionBloqueo);
        return 'PIN incorrecto. Bloqueado por ${duracionBloqueo.inSeconds} s';
      }
      _fallos[u.id] = fallos;
      return 'PIN incorrecto (${intentosMaximos - fallos} intentos restantes)';
    }
    _fallos.remove(u.id);
    _bloqueadoHasta.remove(u.id);
    actual = verificado;
    notifyListeners();
    return null;
  }

  void cerrarSesion() {
    actual = null;
    notifyListeners();
  }

  // --- Administración de usuarios (solo admin) ---

  void _exigirAdmin() {
    if (!esAdmin) throw AppException('Solo un administrador puede hacer esto');
  }

  Future<void> crearUsuario(String nombre, Rol rol, String pin) async {
    _exigirAdmin();
    await _repo.crear(nombre: nombre, rol: rol, pin: pin);
    await cargar();
  }

  Future<void> actualizarUsuario(Usuario u) async {
    _exigirAdmin();
    if (u.id == actual!.id && !u.activo) {
      throw AppException('No puede desactivar su propio usuario');
    }
    await _repo.actualizar(u);
    if (u.id == actual!.id) actual = u;
    await cargar();
  }

  Future<void> cambiarPin(Usuario u, String pin) async {
    _exigirAdmin();
    await _repo.cambiarPin(u.id, pin);
  }
}
