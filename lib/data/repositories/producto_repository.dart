import '../../models/producto.dart';
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
}
