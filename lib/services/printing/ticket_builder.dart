import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../models/printer_config.dart';
import '../../models/venta.dart';
import '../../utils/formato.dart';

/// Genera los bytes ESC/POS de la comanda de cocina y del recibo del cliente.
class TicketBuilder {
  final PrinterConfig config;
  TicketBuilder(this.config);

  Future<Generator> _generador() async {
    final perfil = await CapabilityProfile.load();
    final papel = config.anchoPapel == 58 ? PaperSize.mm58 : PaperSize.mm80;
    return Generator(papel, perfil);
  }

  /// Comanda para cocina: letra grande, sin precios.
  Future<List<int>> comanda(Venta venta) async {
    final g = await _generador();
    final b = <int>[];

    b.addAll(g.text(
      'COMANDA #${venta.id ?? '-'}',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    b.addAll(g.text(
      _t('${venta.tipo.etiqueta.toUpperCase()}'
          '${_ref(venta)}'),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    ));
    b.addAll(g.text(fechaHora(venta.fecha),
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.hr(ch: '='));

    for (final item in venta.items) {
      b.addAll(g.text(
        _t('${item.cantidad} x ${item.nombre}'),
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ));
      if (item.nota?.isNotEmpty ?? false) {
        b.addAll(g.text(_t('   > ${item.nota}')));
      }
    }

    if (venta.nota?.isNotEmpty ?? false) {
      b.addAll(g.hr());
      b.addAll(g.text(_t('NOTA: ${venta.nota}'),
          styles: const PosStyles(bold: true)));
    }

    b.addAll(g.hr(ch: '='));
    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return b;
  }

  /// Recibo para el cliente, con precios y total.
  Future<List<int>> recibo(Venta venta) async {
    final g = await _generador();
    final b = <int>[];

    b.addAll(g.text(
      _t(config.nombreNegocio),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    b.addAll(g.text('Pedido #${venta.id ?? '-'}  ${fechaHora(venta.fecha)}',
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.text(_t('${venta.tipo.etiqueta}${_ref(venta)}'),
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.hr());

    for (final item in venta.items) {
      b.addAll(g.row([
        PosColumn(text: '${item.cantidad}', width: 1),
        PosColumn(text: _t(item.nombre), width: 7),
        PosColumn(
          text: dinero(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    b.addAll(g.hr());
    b.addAll(g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: dinero(venta.total),
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
        ),
      ),
    ]));
    b.addAll(g.text('Pago: ${venta.metodoPago.etiqueta}'));
    b.addAll(g.feed(1));
    b.addAll(g.text('Gracias por su compra!',
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return b;
  }

  Future<List<int>> prueba() async {
    final g = await _generador();
    return [
      ...g.text('PRUEBA DE IMPRESION',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
      ...g.text(_t(config.nombreNegocio),
          styles: const PosStyles(align: PosAlign.center)),
      ...g.text(_t(config.descripcion),
          styles: const PosStyles(align: PosAlign.center)),
      ...g.text('Papel ${config.anchoPapel} mm',
          styles: const PosStyles(align: PosAlign.center)),
      ...g.hr(),
      ...g.feed(2),
      ...g.cut(),
    ];
  }

  String _ref(Venta v) =>
      (v.referencia?.isNotEmpty ?? false) ? ' - ${v.referencia}' : '';

  /// Muchas impresoras térmicas genéricas no soportan tildes/ñ en su página
  /// de códigos por defecto; se normaliza el texto a ASCII.
  static String _t(String s) {
    const mapa = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
      '¡': '!', '¿': '?',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      final reemplazo = mapa[c];
      if (reemplazo != null) {
        sb.write(reemplazo);
      } else if (r < 128) {
        sb.write(c);
      }
    }
    return sb.toString();
  }
}
