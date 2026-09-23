import 'package:sqflite/sqflite.dart';

import '../../models/usuario.dart';
import '../../services/auth/pin_hasher.dart';
import '../../utils/app_exception.dart';
import '../app_database.dart';

class UsuarioRepository {
  final AppDatabase _app;
  UsuarioRepository([AppDatabase? app]) : _app = app ?? AppDatabase.instance;

  static const _columnas = ['id', 'nombre', 'rol', 'activo'];

  Future<List<Usuario>> todos() async {
    final db = await _app.database;
    final filas = await db.query('usuarios',
        columns: _columnas, orderBy: 'activo DESC, nombre');
    return filas.map(Usuario.fromMap).toList();
  }

  Future<int> contar() async {
    final db = await _app.database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM usuarios')) ??
        0;
  }

  Future<Usuario> crear({
    required String nombre,
    required Rol rol,
    required String pin,
  }) async {
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) throw AppException('Ingrese un nombre');
    final errorPin = PinHasher.validar(pin);
    if (errorPin != null) throw AppException(errorPin);

    final sal = PinHasher.nuevaSal();
    final hash = await PinHasher.hash(pin, sal, PinHasher.iteraciones);
    final db = await _app.database;
    try {
      final id = await db.insert('usuarios', {
        'nombre': nombreLimpio,
        'rol': rol.name,
        'pin_hash': hash,
        'pin_salt': sal,
        'iteraciones': PinHasher.iteraciones,
        'activo': 1,
        'creado': DateTime.now().toIso8601String(),
      });
      return Usuario(id: id, nombre: nombreLimpio, rol: rol);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException('Ya existe un usuario llamado "$nombreLimpio"');
      }
      rethrow;
    }
  }

  /// Devuelve el usuario si el PIN es correcto y está activo.
  Future<Usuario?> verificar(int id, String pin) async {
    final db = await _app.database;
    final filas = await db.query('usuarios',
        where: 'id = ? AND activo = 1', whereArgs: [id], limit: 1);
    if (filas.isEmpty) return null;
    final f = filas.first;
    final ok = await PinHasher.verificar(
      pin,
      f['pin_salt'] as String,
      f['iteraciones'] as int,
      f['pin_hash'] as String,
    );
    return ok ? Usuario.fromMap(f) : null;
  }

  Future<void> cambiarPin(int id, String pin) async {
    final errorPin = PinHasher.validar(pin);
    if (errorPin != null) throw AppException(errorPin);
    final sal = PinHasher.nuevaSal();
    final hash = await PinHasher.hash(pin, sal, PinHasher.iteraciones);
    final db = await _app.database;
    await db.update(
      'usuarios',
      {'pin_hash': hash, 'pin_salt': sal, 'iteraciones': PinHasher.iteraciones},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Actualiza nombre, rol y estado. Siempre debe quedar un admin activo.
  Future<void> actualizar(Usuario u) async {
    final db = await _app.database;
    if (!u.esAdmin || !u.activo) {
      final otrosAdmins = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM usuarios "
            "WHERE rol = 'admin' AND activo = 1 AND id <> ?",
            [u.id],
          )) ??
          0;
      if (otrosAdmins == 0) {
        throw AppException('Debe quedar al menos un administrador activo');
      }
    }
    try {
      await db.update(
        'usuarios',
        {
          'nombre': u.nombre.trim(),
          'rol': u.rol.name,
          'activo': u.activo ? 1 : 0
        },
        where: 'id = ?',
        whereArgs: [u.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException('Ya existe un usuario llamado "${u.nombre.trim()}"');
      }
      rethrow;
    }
  }
}
