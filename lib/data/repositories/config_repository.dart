import 'package:sqflite/sqflite.dart';

import '../../models/printer_config.dart';
import '../app_database.dart';

/// Configuración clave/valor persistida en SQLite.
class ConfigRepository {
  final AppDatabase _app;
  ConfigRepository([AppDatabase? app]) : _app = app ?? AppDatabase.instance;

  Future<PrinterConfig> cargarImpresora() async {
    final db = await _app.database;
    final filas = await db.query('configuracion');
    return PrinterConfig.fromMap({
      for (final f in filas) f['clave'] as String: f['valor'] as String,
    });
  }

  Future<void> guardarImpresora(PrinterConfig config) =>
      escribir(config.toMap());

  Future<String?> leer(String clave) async {
    final db = await _app.database;
    final filas = await db.query('configuracion',
        where: 'clave = ?', whereArgs: [clave], limit: 1);
    return filas.isEmpty ? null : filas.first['valor'] as String;
  }

  Future<void> escribir(Map<String, String> valores) async {
    final db = await _app.database;
    final batch = db.batch();
    valores.forEach((clave, valor) {
      batch.insert('configuracion', {'clave': clave, 'valor': valor},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }
}
