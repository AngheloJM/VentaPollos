import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acceso único a la base SQLite local del dispositivo.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _archivo = 'venta_pollos.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _abrir();

  Future<Database> _abrir() async {
    final ruta = join(await getDatabasesPath(), _archivo);
    return openDatabase(
      ruta,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _crear,
      // onUpgrade: agregar migraciones aquí al subir _version.
    );
  }

  Future<void> _crear(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE categorias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🍗',
        orden INTEGER NOT NULL DEFAULT 0
      )''');

    batch.execute('''
      CREATE TABLE productos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER NOT NULL REFERENCES categorias(id),
        nombre TEXT NOT NULL,
        precio INTEGER NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🍗',
        activo INTEGER NOT NULL DEFAULT 1
      )''');

    batch.execute('''
      CREATE TABLE ventas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        tipo TEXT NOT NULL,
        referencia TEXT,
        nota TEXT,
        metodo_pago TEXT NOT NULL,
        total INTEGER NOT NULL,
        anulada INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('CREATE INDEX idx_ventas_fecha ON ventas(fecha)');

    // Se copia nombre y precio para que el historial no cambie
    // si luego se edita o elimina el producto.
    batch.execute('''
      CREATE TABLE venta_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
        producto_id INTEGER,
        nombre TEXT NOT NULL,
        precio INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        nota TEXT
      )''');

    batch.execute('''
      CREATE TABLE configuracion(
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )''');

    _datosIniciales(batch);
    await batch.commit(noResult: true);
  }

  /// Catálogo de ejemplo; se puede editar desde la pantalla Productos.
  void _datosIniciales(Batch b) {
    b.insert(
        'categorias', {'id': 1, 'nombre': 'Pollos', 'emoji': '🍗', 'orden': 0});
    b.insert(
        'categorias', {'id': 2, 'nombre': 'Combos', 'emoji': '🍱', 'orden': 1});
    b.insert(
        'categorias', {'id': 3, 'nombre': 'Extras', 'emoji': '🍟', 'orden': 2});
    b.insert('categorias',
        {'id': 4, 'nombre': 'Bebidas', 'emoji': '🥤', 'orden': 3});

    const productos = [
      (1, 'Pollo entero', 9000, '🍗'),
      (1, '1/2 Pollo', 4800, '🍗'),
      (1, '1/4 Pollo', 2500, '🍗'),
      (1, '1/8 Pollo', 1500, '🍗'),
      (2, 'Combo familiar', 11500, '🍱'),
      (2, 'Combo personal', 3000, '🍱'),
      (3, 'Papas fritas', 1200, '🍟'),
      (3, 'Arroz', 800, '🍚'),
      (3, 'Ensalada', 800, '🥗'),
      (4, 'Gaseosa 2L', 1500, '🥤'),
      (4, 'Gaseosa personal', 700, '🥤'),
      (4, 'Refresco natural', 800, '🧃'),
    ];
    for (final (cat, nombre, precio, emoji) in productos) {
      b.insert('productos', {
        'categoria_id': cat,
        'nombre': nombre,
        'precio': precio,
        'emoji': emoji,
      });
    }
  }
}
