import 'package:sqflite/sqflite.dart';

import '../../models/producto.dart';
import '../../utils/app_exception.dart';
import '../app_database.dart';

class ProductoRepository {
  final AppDatabase _app;
  ProductoRepository([AppDatabase? app]) : _app = app ?? AppDatabase.instance;

  Future<List<Categoria>> categorias() async {
    final db = await _app.database;
    final filas = await db.query('categorias', orderBy: 'orden, id');
    return filas.map(Categoria.fromMap).toList();
  }

  Future<List<Producto>> productos() async {
    final db = await _app.database;
    final filas = await db.query('productos', orderBy: 'categoria_id, id');
    return filas.map(Producto.fromMap).toList();
  }

  Future<Producto> guardar(Producto p) async {
    final db = await _app.database;
    if (p.id == null) {
      final id = await db.insert('productos', p.toMap());
      return Producto.fromMap({...p.toMap(), 'id': id});
    }
    await db.update('productos', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    return p;
  }

  Future<void> eliminar(int id) async {
    final db = await _app.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<Categoria> guardarCategoria(Categoria c) async {
    final db = await _app.database;
    if (c.id == null) {
      final id = await db.insert('categorias', c.toMap());
      return Categoria.fromMap({...c.toMap(), 'id': id});
    }
    await db
        .update('categorias', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    return c;
  }

  /// Solo se eliminan categorías vacías, para no dejar productos huérfanos.
  Future<void> eliminarCategoria(int id) async {
    final db = await _app.database;
    final productos = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM productos WHERE categoria_id = ?', [id])) ??
        0;
    if (productos > 0) {
      throw AppException(
          'La categoría tiene $productos producto(s). Muévalos o elimínelos primero.');
    }
    await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }
}
