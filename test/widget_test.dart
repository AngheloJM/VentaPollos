import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:venta_pollos/models/printer_config.dart';
import 'package:venta_pollos/models/producto.dart';
import 'package:venta_pollos/models/usuario.dart';
import 'package:venta_pollos/models/venta.dart';
import 'package:venta_pollos/providers/carrito_provider.dart';
import 'package:venta_pollos/services/auth/pin_hasher.dart';
import 'package:venta_pollos/services/printing/escpos_renderer.dart';
import 'package:venta_pollos/services/printing/ticket.dart';
import 'package:venta_pollos/services/printing/ticket_formatter.dart';
import 'package:venta_pollos/utils/formato.dart';
import 'package:venta_pollos/widgets/ticket_preview.dart';

const _cajero = Usuario(id: 2, nombre: 'Lucía', rol: Rol.cajero);

Venta _ventaEjemplo() => Venta(
      id: 7,
      fecha: DateTime(2026, 9, 23, 12, 30),
      tipo: TipoPedido.llevar,
      referencia: 'Señora Ána',
      metodoPago: MetodoPago.qr,
      usuarioNombre: 'Lucía',
      items: const [
        VentaItem(
            nombre: 'Combo familiar',
            descripcion: '1 pollo + papas',
            precio: 11500,
            cantidad: 1,
            nota: 'bien dorado'),
        VentaItem(nombre: 'Gaseosa 2L', precio: 1500, cantidad: 2),
      ],
    );

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

  group('PIN', () {
    test('valida formato de 4 a 8 dígitos', () {
      expect(PinHasher.validar('1234'), isNull);
      expect(PinHasher.validar('123'), isNotNull);
      expect(PinHasher.validar('12a4'), isNotNull);
      expect(PinHasher.validar('123456789'), isNotNull);
    });

    test('el hash verifica el PIN correcto y rechaza otro', () async {
      final sal = PinHasher.nuevaSal();
      final hash = await PinHasher.hash('4821', sal, 1000);
      expect(hash, isNot(contains('4821')));
      expect(await PinHasher.verificar('4821', sal, 1000, hash), isTrue);
      expect(await PinHasher.verificar('4822', sal, 1000, hash), isFalse);
    });

    test('la sal es distinta en cada usuario', () {
      expect(PinHasher.nuevaSal(), isNot(PinHasher.nuevaSal()));
    });
  });

  test('PrinterConfig se conserva al guardar y leer', () {
    const c = PrinterConfig(
      conexion: TipoConexion.pantalla,
      anchoPapel: 58,
      imprimirRecibo: true,
    );
    final leida = PrinterConfig.fromMap(c.toMap());
    expect(leida.conexion, TipoConexion.pantalla);
    expect(leida.esPantalla, isTrue);
    expect(leida.anchoPapel, 58);
    expect(leida.imprimirRecibo, isTrue);
  });

  group('carrito', () {
    const pollo =
        Producto(id: 1, categoriaId: 1, nombre: '1/4 Pollo', precio: 2500);
    const combo = Producto(
        id: 2,
        categoriaId: 2,
        nombre: 'Combo',
        descripcion: '1/4 + papas',
        precio: 3000);

    test('agrega, suma y genera la venta con usuario y contenido', () {
      final c = CarritoProvider()
        ..agregar(pollo)
        ..agregar(pollo)
        ..agregar(combo)
        ..setTipo(TipoPedido.mesa)
        ..referencia = ' 5 ';
      expect(c.unidades, 3);
      expect(c.total, 8000);

      final v = c.aVenta(_cajero);
      expect(v.total, 8000);
      expect(v.referencia, '5');
      expect(v.usuarioNombre, 'Lucía');
      expect(v.items.last.descripcion, '1/4 + papas');
    });

    test('quitar hasta cero elimina la línea', () {
      final c = CarritoProvider()..agregar(pollo);
      c.cambiarCantidad(c.lineas.first, -1);
      expect(c.vacio, isTrue);
    });
  });

  group('tickets', () {
    test('la comanda no lleva precios y el texto queda sin tildes', () {
      final doc =
          TicketFormatter(const PrinterConfig()).comanda(_ventaEjemplo());
      final textos = doc.lineas.whereType<TextoTicket>().map((t) => t.texto);
      expect(textos, contains('PARA LLEVAR - Senora Ana'));
      expect(textos, contains('    (1 pollo + papas)'));
      expect(textos, contains('    > bien dorado'));
      expect(textos, contains('Atiende: Lucia'));
      expect(textos.any((t) => t.contains('Bs')), isFalse);
      expect(doc.lineas.last, isA<CorteTicket>());
    });

    test('en 58 mm el texto largo se reparte por palabras', () {
      final v = _ventaEjemplo();
      final largo = Venta(
        fecha: v.fecha,
        tipo: v.tipo,
        metodoPago: v.metodoPago,
        items: const [
          VentaItem(
              nombre: 'Combo',
              descripcion: '1 pollo + papas familiares + gaseosa 2L',
              precio: 100,
              cantidad: 1),
        ],
      );
      final doc =
          TicketFormatter(const PrinterConfig(anchoPapel: 58)).comanda(largo);
      final textos =
          doc.lineas.whereType<TextoTicket>().map((t) => t.texto).toList();
      expect(textos, contains('    (1 pollo + papas familiares'));
      expect(textos, contains('     + gaseosa 2L)'));
      expect(textos.every((t) => t.length <= 32), isTrue);
    });

    test('genera bytes ESC/POS de comanda y recibo', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final f = TicketFormatter(const PrinterConfig(anchoPapel: 58));
      final r = EscPosRenderer(58);
      final comanda = await r.render(f.comanda(_ventaEjemplo()));
      final recibo = await r.render(f.recibo(_ventaEjemplo()));
      expect(comanda.take(2), [0x1B, 0x40]); // ESC @ (inicializar)
      expect(String.fromCharCodes(recibo), contains('TOTAL'));
      expect(String.fromCharCodes(recibo), contains('Bs 145.00'));
    });

    for (final ancho in [58, 80]) {
      testWidgets('la vista previa dibuja recibo de $ancho mm sin errores',
          (tester) async {
        final doc = TicketFormatter(PrinterConfig(anchoPapel: ancho))
            .recibo(_ventaEjemplo());
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TicketPapel(doc: doc, anchoPapel: ancho),
            ),
          ),
        ));
        expect(find.textContaining('TOTAL'), findsOneWidget);
        expect(find.textContaining('Gracias'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
