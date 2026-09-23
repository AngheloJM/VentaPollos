import '../../models/venta.dart';
import '../app_database.dart';

class VentaRepository {
  final AppDatabase _app;
  VentaRepository([AppDatabase? app]) : _app = app ?? AppDatabase.instance;

  /// Guarda la venta y sus ítems en una sola transacción.
  Future<Venta> registrar(Venta venta) async {
    final db = await _app.database;
    final id = await db.transaction((txn) async {
      final ventaId = await txn.insert('ventas', venta.toMap());
      for (final item in venta.items) {
        await txn.insert('venta_items', item.toMap(ventaId));
      }
      return ventaId;
    });
    return venta.conId(id);
  }

  Future<List<Venta>> delDia(DateTime dia) async {
    final db = await _app.database;
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = inicio.add(const Duration(days: 1));

    final ventas = await db.query(
      'ventas',
      where: 'fecha >= ? AND fecha < ?',
      whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    if (ventas.isEmpty) return [];

    final ids = ventas.map((v) => v['id']).toList();
    final items = await db.query(
      'venta_items',
      where: 'venta_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'id',
    );

    final porVenta = <int, List<VentaItem>>{};
    for (final fila in items) {
      porVenta
          .putIfAbsent(fila['venta_id'] as int, () => [])
          .add(VentaItem.fromMap(fila));
    }
    return ventas
        .map((v) => Venta.fromMap(v, porVenta[v['id']] ?? const []))
        .toList();
  }

  Future<void> anular(int id) async {
    final db = await _app.database;
    await db.update('ventas', {'anulada': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
