import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acceso único a la base SQLite local del dispositivo.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _archivo = 'venta_pollos.db';
  static const _version = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _abrir();

  Future<Database> _abrir() async {
    final ruta = join(await getDatabasesPath(), _archivo);
    return openDatabase(
      ruta,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await _v1(db);
        await _v2(db);
      },
      // Migraciones incrementales: conservan los datos ya registrados.
      onUpgrade: (db, anterior, _) async {
        if (anterior < 2) await _v2(db);
      },
    );
  }

  Future<void> _v1(Database db) async {
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

  /// v2: usuarios con PIN, contenido de combos y usuario en cada venta.
  Future<void> _v2(Database db) async {
    final b = db.batch();
    b.execute('ALTER TABLE productos ADD COLUMN descripcion TEXT');
    b.execute('ALTER TABLE venta_items ADD COLUMN descripcion TEXT');
    b.execute('ALTER TABLE ventas ADD COLUMN usuario_id INTEGER');
    b.execute('ALTER TABLE ventas ADD COLUMN usuario_nombre TEXT');
    b.execute('''
      CREATE TABLE usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE,
        rol TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        iteraciones INTEGER NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        creado TEXT NOT NULL
      )''');
    b.update(
        'productos', {'descripcion': '1 pollo + papas familiares + gaseosa 2L'},
        where: 'nombre = ? AND descripcion IS NULL',
        whereArgs: ['Combo familiar']);
    b.update('productos',
        {'descripcion': '1/4 pollo + papas + arroz + gaseosa personal'},
        where: 'nombre = ? AND descripcion IS NULL',
        whereArgs: ['Combo personal']);
    await b.commit(noResult: true);
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
