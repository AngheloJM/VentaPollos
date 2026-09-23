import 'package:flutter/foundation.dart';

import '../data/repositories/config_repository.dart';
import '../models/printer_config.dart';
import '../models/venta.dart';
import '../services/printing/printer_transport.dart';
import '../services/printing/ticket_builder.dart';

class ImpresoraProvider extends ChangeNotifier {
  final ConfigRepository _repo;
  ImpresoraProvider(this._repo);

  PrinterConfig _config = const PrinterConfig();
  PrinterConfig get config => _config;

  bool _cargado = false;
  bool get cargado => _cargado;

  bool _imprimiendo = false;
  bool get imprimiendo => _imprimiendo;

  Future<void> cargar() async {
    _config = await _repo.cargarImpresora();
    _cargado = true;
    notifyListeners();
  }

  Future<void> guardar(PrinterConfig nueva) async {
    if (_config.conexion == TipoConexion.bluetooth &&
        _config.bluetoothMac != nueva.bluetoothMac) {
      await BluetoothTransport.desconectar();
    }
    _config = nueva;
    await _repo.guardarImpresora(nueva);
    notifyListeners();
  }

  /// Imprime la comanda de cocina y, si está habilitado, el recibo.
  Future<void> imprimirVenta(Venta venta, {bool? conRecibo}) async {
    final builder = TicketBuilder(_config);
    await _enviar([
      await builder.comanda(venta),
      if (conRecibo ?? _config.imprimirRecibo) await builder.recibo(venta),
    ]);
  }

  Future<void> imprimirRecibo(Venta venta) async =>
      _enviar([await TicketBuilder(_config).recibo(venta)]);

  Future<void> imprimirPrueba([PrinterConfig? c]) async {
    final cfg = c ?? _config;
    await _enviar([await TicketBuilder(cfg).prueba()], cfg);
  }

  Future<void> _enviar(List<List<int>> tickets, [PrinterConfig? c]) async {
    final cfg = c ?? _config;
    if (!cfg.configurada) {
      throw ImpresionException('Configure una impresora en Ajustes');
    }
    if (_imprimiendo) throw ImpresionException('Impresión en curso');
    _imprimiendo = true;
    notifyListeners();
    try {
      final transporte = PrinterTransport.desde(cfg);
      for (final t in tickets) {
        await transporte.enviar(t);
      }
    } finally {
      _imprimiendo = false;
      notifyListeners();
    }
  }
}
