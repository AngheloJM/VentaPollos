import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:venta_pollos/models/printer_config.dart';
import 'package:venta_pollos/models/producto.dart';
import 'package:venta_pollos/models/venta.dart';
import 'package:venta_pollos/providers/carrito_provider.dart';
import 'package:venta_pollos/services/printing/ticket_builder.dart';
import 'package:venta_pollos/utils/formato.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('formato', () {
    test('parsea montos con punto o coma a centavos', () {
      expect(parsearDinero('12.50'), 1250);
      expect(parsearDinero('12,5'), 1250);
      expect(parsearDinero('abc'), isNull);
      expect(parsearDinero('-1'), isNull);
    });

    test('formatea centavos', () {
      expect(dinero(4800), 'Bs 48.00');
    });
  });

  test('PrinterConfig se conserva al guardar y leer', () {
    const c = PrinterConfig(
      conexion: TipoConexion.red,
      ip: '192.168.1.50',
      puerto: 9100,
      anchoPapel: 58,
      imprimirRecibo: true,
    );
    final leida = PrinterConfig.fromMap(c.toMap());
    expect(leida.conexion, TipoConexion.red);
    expect(leida.ip, '192.168.1.50');
    expect(leida.anchoPapel, 58);
    expect(leida.imprimirRecibo, isTrue);
    expect(leida.configurada, isTrue);
  });

  group('carrito', () {
    const pollo =
        Producto(id: 1, categoriaId: 1, nombre: '1/4 Pollo', precio: 2500);
    const papas =
        Producto(id: 2, categoriaId: 3, nombre: 'Papas', precio: 1200);

    test('agrega, suma y genera la venta', () {
      final c = CarritoProvider()
        ..agregar(pollo)
        ..agregar(pollo)
        ..agregar(papas)
        ..setTipo(TipoPedido.mesa)
        ..referencia = ' 5 ';
      expect(c.unidades, 3);
      expect(c.total, 6200);

      final v = c.aVenta();
      expect(v.total, 6200);
      expect(v.referencia, '5');
      expect(v.items.first.cantidad, 2);
    });

    test('quitar hasta cero elimina la línea', () {
      final c = CarritoProvider()..agregar(pollo);
      c.cambiarCantidad(c.lineas.first, -1);
      expect(c.vacio, isTrue);
    });
  });

  test('genera bytes ESC/POS de comanda y recibo', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final venta = Venta(
      id: 7,
      fecha: DateTime(2026, 9, 23, 12, 30),
      tipo: TipoPedido.llevar,
      referencia: 'Señora Ána',
      metodoPago: MetodoPago.qr,
      items: const [
        VentaItem(
            nombre: 'Pollo entero',
            precio: 9000,
            cantidad: 1,
            nota: 'bien dorado')
      ],
    );
    final b = TicketBuilder(const PrinterConfig(anchoPapel: 80));
    expect(await b.comanda(venta), isNotEmpty);
    expect(await b.recibo(venta), isNotEmpty);
  });
}
