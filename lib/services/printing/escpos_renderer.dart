import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'ticket.dart';

/// Convierte un [TicketDoc] en bytes ESC/POS para impresoras térmicas.
class EscPosRenderer {
  final int anchoPapel;
  EscPosRenderer(this.anchoPapel);

  Future<List<int>> render(TicketDoc doc) async {
    final perfil = await CapabilityProfile.load();
    final g =
        Generator(anchoPapel == 58 ? PaperSize.mm58 : PaperSize.mm80, perfil);

    final b = <int>[...g.reset()];
    for (final linea in doc.lineas) {
      switch (linea) {
        case final TextoTicket t:
          b.addAll(g.text(
            t.texto,
            styles: PosStyles(
              align: _alinear(t.alineacion),
              bold: t.negrita,
              height: t.altoDoble ? PosTextSize.size2 : PosTextSize.size1,
              width: t.anchoDoble ? PosTextSize.size2 : PosTextSize.size1,
            ),
          ));
        case final FilaTicket f:
          b.addAll(g.row([
            for (final c in f.columnas)
              PosColumn(
                text: c.texto,
                width: c.ancho,
                styles: PosStyles(
                  align: _alinear(c.alineacion),
                  bold: c.negrita,
                  height: c.altoDoble ? PosTextSize.size2 : PosTextSize.size1,
                ),
              ),
          ]));
        case final SeparadorTicket s:
          b.addAll(g.hr(ch: s.caracter));
        case final AvanceTicket a:
          b.addAll(g.feed(a.lineas));
        case CorteTicket():
          b.addAll(g.cut());
      }
    }
    return b;
  }

  static PosAlign _alinear(Alineacion a) => switch (a) {
        Alineacion.izquierda => PosAlign.left,
        Alineacion.centro => PosAlign.center,
        Alineacion.derecha => PosAlign.right,
      };
}
