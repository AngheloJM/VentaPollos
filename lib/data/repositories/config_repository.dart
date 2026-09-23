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

  Future<void> guardarImpresora(PrinterConfig config) async {
    final db = await _app.database;
    final batch = db.batch();
    config.toMap().forEach((clave, valor) {
      batch.insert(
        'configuracion',
        {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }
}
