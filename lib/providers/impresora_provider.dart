import 'package:flutter/foundation.dart';

import '../data/repositories/config_repository.dart';
import '../models/printer_config.dart';
import '../models/venta.dart';
import '../services/printing/escpos_renderer.dart';
import '../services/printing/printer_transport.dart';
import '../services/printing/ticket.dart';
import '../services/printing/ticket_formatter.dart';

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

  /// Tickets de una venta: comanda y, según configuración, recibo.
  List<TicketDoc> ticketsVenta(
    Venta venta, {
    bool comanda = true,
    bool? recibo,
    PrinterConfig? config,
  }) {
    final cfg = config ?? _config;
    final f = TicketFormatter(cfg);
    return [
      if (comanda) f.comanda(venta),
      if (recibo ?? cfg.imprimirRecibo) f.recibo(venta),
    ];
  }

  TicketDoc ticketPrueba([PrinterConfig? config]) =>
      TicketFormatter(config ?? _config).prueba();

  /// Envía los tickets a la impresora física configurada.
  Future<void> imprimir(List<TicketDoc> tickets, [PrinterConfig? c]) async {
    final cfg = c ?? _config;
    if (!cfg.configurada || cfg.esPantalla) {
      throw ImpresionException('Configure una impresora física en Admin');
    }
    if (_imprimiendo) throw ImpresionException('Impresión en curso');
    _imprimiendo = true;
    notifyListeners();
    try {
      final transporte = PrinterTransport.desde(cfg);
      final renderer = EscPosRenderer(cfg.anchoPapel);
      for (final t in tickets) {
        await transporte.enviar(await renderer.render(t));
      }
    } finally {
      _imprimiendo = false;
      notifyListeners();
    }
  }
}
