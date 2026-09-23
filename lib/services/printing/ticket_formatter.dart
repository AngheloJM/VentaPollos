import '../../models/printer_config.dart';
import '../../models/venta.dart';
import '../../utils/formato.dart';
import 'ticket.dart';

/// Define el contenido y diseño de la comanda, el recibo y la prueba.
class TicketFormatter {
  final PrinterConfig config;
  TicketFormatter(this.config);

  /// Comanda para cocina: letra grande, sin precios.
  TicketDoc comanda(Venta venta) {
    return TicketDoc('Comanda', [
      TextoTicket(
        'COMANDA #${venta.id ?? '-'}',
        alineacion: Alineacion.centro,
        negrita: true,
        altoDoble: true,
        anchoDoble: true,
      ),
      TextoTicket(
        _t('${venta.tipo.etiqueta.toUpperCase()}${_ref(venta)}'),
        alineacion: Alineacion.centro,
        negrita: true,
        altoDoble: true,
      ),
      TextoTicket(fechaHora(venta.fecha), alineacion: Alineacion.centro),
      if (venta.usuarioNombre != null)
        TextoTicket(_t('Atiende: ${venta.usuarioNombre}'),
            alineacion: Alineacion.centro),
      const SeparadorTicket('='),
      for (final item in venta.items) ...[
        ..._parrafo('${item.cantidad} x ${item.nombre}',
            negrita: true, altoDoble: true, sangria: '    '),
        if (item.descripcion?.isNotEmpty ?? false)
          ..._parrafo('(${item.descripcion})',
              primera: '    ', sangria: '     '),
        if (item.nota?.isNotEmpty ?? false)
          ..._parrafo('> ${item.nota}',
              primera: '    ', sangria: '      ', negrita: true),
      ],
      if (venta.nota?.isNotEmpty ?? false) ...[
        const SeparadorTicket(),
        ..._parrafo('NOTA: ${venta.nota}', negrita: true, sangria: '      '),
      ],
      const SeparadorTicket('='),
      const AvanceTicket(2),
      const CorteTicket(),
    ]);
  }

  /// Recibo para el cliente, con precios y total.
  TicketDoc recibo(Venta venta) {
    return TicketDoc('Recibo', [
      TextoTicket(
        _t(config.nombreNegocio),
        alineacion: Alineacion.centro,
        negrita: true,
        altoDoble: true,
        anchoDoble: true,
      ),
      TextoTicket('Pedido #${venta.id ?? '-'}  ${fechaHora(venta.fecha)}',
          alineacion: Alineacion.centro),
      TextoTicket(_t('${venta.tipo.etiqueta}${_ref(venta)}'),
          alineacion: Alineacion.centro),
      if (venta.usuarioNombre != null)
        TextoTicket(_t('Atendido por: ${venta.usuarioNombre}'),
            alineacion: Alineacion.centro),
      const SeparadorTicket(),
      FilaTicket(const [
        ColumnaTicket('Producto', 8, negrita: true),
        ColumnaTicket('Importe', 4,
            negrita: true, alineacion: Alineacion.derecha),
      ]),
      for (final item in venta.items)
        FilaTicket([
          ColumnaTicket(_t('${item.cantidad} x ${item.nombre}'), 8),
          ColumnaTicket(dinero(item.subtotal), 4,
              alineacion: Alineacion.derecha),
        ]),
      const SeparadorTicket(),
      FilaTicket([
        const ColumnaTicket('TOTAL', 6, negrita: true, altoDoble: true),
        ColumnaTicket(dinero(venta.total), 6,
            negrita: true, altoDoble: true, alineacion: Alineacion.derecha),
      ]),
      TextoTicket('Pago: ${venta.metodoPago.etiqueta}'),
      const AvanceTicket(),
      const TextoTicket('Gracias por su compra!',
          alineacion: Alineacion.centro),
      const AvanceTicket(2),
      const CorteTicket(),
    ]);
  }

  TicketDoc prueba() {
    return TicketDoc('Prueba', [
      const TextoTicket(
        'PRUEBA',
        alineacion: Alineacion.centro,
        negrita: true,
        altoDoble: true,
        anchoDoble: true,
      ),
      TextoTicket(_t(config.nombreNegocio), alineacion: Alineacion.centro),
      TextoTicket(_t(config.descripcion), alineacion: Alineacion.centro),
      TextoTicket(
          'Papel ${config.anchoPapel} mm - '
          '${columnasPapel(config.anchoPapel)} columnas',
          alineacion: Alineacion.centro),
      const SeparadorTicket(),
      const TextoTicket('Izquierda'),
      const TextoTicket('Centro', alineacion: Alineacion.centro),
      const TextoTicket('Derecha', alineacion: Alineacion.derecha),
      const TextoTicket('Negrita', negrita: true),
      const TextoTicket('Alto doble', altoDoble: true),
      const TextoTicket('Doble', altoDoble: true, anchoDoble: true),
      const SeparadorTicket(),
      const AvanceTicket(2),
      const CorteTicket(),
    ]);
  }

  int get _columnas => columnasPapel(config.anchoPapel);

  /// Reparte el texto en líneas por palabras (la impresora cortaría a mitad
  /// de palabra). [primera] antecede a la primera línea y [sangria] al resto.
  List<TextoTicket> _parrafo(
    String texto, {
    String primera = '',
    String sangria = '',
    bool negrita = false,
    bool altoDoble = false,
  }) {
    final lineas = <String>[];
    var actual = primera;
    for (final palabra in _t(texto).split(' ').where((p) => p.isNotEmpty)) {
      final base = lineas.isEmpty ? primera : sangria;
      final candidata =
          actual.length > base.length ? '$actual $palabra' : '$actual$palabra';
      if (candidata.length <= _columnas || actual.length <= base.length) {
        actual = candidata;
      } else {
        lineas.add(actual);
        actual = '$sangria$palabra';
      }
    }
    lineas.add(actual);
    return [
      for (final l in lineas)
        TextoTicket(l, negrita: negrita, altoDoble: altoDoble),
    ];
  }

  String _ref(Venta v) =>
      (v.referencia?.isNotEmpty ?? false) ? ' - ${v.referencia}' : '';

  /// Muchas impresoras térmicas genéricas no soportan tildes/ñ en su página
  /// de códigos por defecto; se normaliza el texto a ASCII.
  static String _t(String s) {
    const mapa = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N', //
      '¡': '!', '¿': '?', '·': '-', '–': '-', '—': '-',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      final reemplazo = mapa[c];
      if (reemplazo != null) {
        sb.write(reemplazo);
      } else if (r >= 32 && r < 127) {
        sb.write(c);
      }
    }
    return sb.toString();
  }
}
