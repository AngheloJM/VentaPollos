import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/impresora_provider.dart';
import '../services/printing/ticket.dart';

/// Si la impresora está en modo "Pantalla" muestra la vista previa;
/// si no, envía los tickets a la impresora física.
Future<void> imprimirOMostrar(
    BuildContext context, List<TicketDoc> tickets) async {
  final impresora = context.read<ImpresoraProvider>();
  if (impresora.config.esPantalla) {
    await mostrarVistaPrevia(context, tickets);
  } else {
    await impresora.imprimir(tickets);
  }
}

Future<void> mostrarVistaPrevia(
  BuildContext context,
  List<TicketDoc> tickets, {
  int? anchoPapel,
}) {
  final impresora = context.read<ImpresoraProvider>();
  final ancho = anchoPapel ?? impresora.config.anchoPapel;
  final puedeImprimir =
      impresora.config.configurada && !impresora.config.esPantalla;

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFFECEFF1),
      insetPadding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Vista previa · $ancho mm',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final t in tickets) ...[
                Text(t.titulo.toUpperCase(),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TicketPapel(doc: t, anchoPapel: ancho),
                ),
                const SizedBox(height: 20),
              ],
            ]),
          ),
        ),
        if (puedeImprimir)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(ctx);
                  Navigator.pop(ctx);
                  try {
                    await impresora.imprimir(tickets);
                    messenger.showSnackBar(
                        const SnackBar(content: Text('Enviado a impresora')));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir'),
              ),
            ),
          ),
      ]),
    ),
  );
}

/// Dibuja el ticket en una rejilla monoespaciada con las mismas columnas
/// que la impresora (32 en 58 mm, 48 en 80 mm).
class TicketPapel extends StatelessWidget {
  final TicketDoc doc;
  final int anchoPapel;
  const TicketPapel({super.key, required this.doc, required this.anchoPapel});

  static const _anchoCaracter = 7.0;
  static const _altoLinea = 15.0;
  static const _estiloBase = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier New', 'Courier'],
    color: Color(0xFF212121),
    height: 1.0,
    // El tema de la app agrega espaciado entre letras; aquí debe ser 0
    // para respetar la rejilla de la impresora.
    letterSpacing: 0,
    wordSpacing: 0,
  );

  int get _cols => columnasPapel(anchoPapel);

  @override
  Widget build(BuildContext context) {
    final tamano = _tamanoFuente();
    final filas = <Widget>[];

    for (final linea in doc.lineas) {
      switch (linea) {
        case final TextoTicket t:
          final cols = t.anchoDoble ? _cols ~/ 2 : _cols;
          for (final parte in _partir(t.texto, cols)) {
            filas.add(_linea(
              _alinear(parte, cols, t.alineacion),
              tamano * (t.anchoDoble ? 2 : 1),
              negrita: t.negrita,
              altoDoble: t.altoDoble && !t.anchoDoble,
              lineas: t.altoDoble ? 2 : 1,
            ));
          }
        case final FilaTicket f:
          final negrita = f.columnas.any((c) => c.negrita);
          final alto = f.columnas.any((c) => c.altoDoble);
          for (final texto in _fila(f)) {
            filas.add(_linea(texto, tamano,
                negrita: negrita, altoDoble: alto, lineas: alto ? 2 : 1));
          }
        case final SeparadorTicket s:
          filas.add(_linea(s.caracter * _cols, tamano));
        case final AvanceTicket a:
          for (var i = 0; i < a.lineas; i++) {
            filas.add(const SizedBox(height: _altoLinea));
          }
        case CorteTicket():
          filas.add(_Corte(ancho: _cols * _anchoCaracter));
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
        borderRadius: BorderRadius.circular(2),
      ),
      child: SizedBox(
        width: _cols * _anchoCaracter,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: filas),
      ),
    );
  }

  /// Tamaño de fuente para que [_cols] caracteres (también en negrita)
  /// quepan exactamente en el ancho del papel.
  double _tamanoFuente() {
    double ancho(double tamano, FontWeight peso) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'M' * _cols,
          style: _estiloBase.copyWith(fontSize: tamano, fontWeight: peso),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      return tp.width;
    }

    final objetivo = _cols * _anchoCaracter;
    var tamano = 12.0;
    // Se ajusta en el tamaño real: el ancho de los glifos no es lineal.
    for (var i = 0; i < 3; i++) {
      final medido = [FontWeight.w400, FontWeight.w800]
          .map((p) => ancho(tamano, p))
          .reduce(max);
      tamano *= objetivo / medido;
    }
    return tamano;
  }

  Widget _linea(
    String texto,
    double tamano, {
    bool negrita = false,
    bool altoDoble = false,
    int lineas = 1,
  }) {
    Widget t = Text(
      texto,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      textScaler: TextScaler.noScaling,
      style: _estiloBase.copyWith(
        fontSize: tamano,
        fontWeight: negrita ? FontWeight.w800 : FontWeight.w400,
      ),
    );
    if (altoDoble) {
      t = Transform(
        alignment: Alignment.topLeft,
        transform: Matrix4.diagonal3Values(1, 2, 1),
        child: t,
      );
    }
    return SizedBox(
      width: _cols * _anchoCaracter,
      height: _altoLinea * lineas,
      child: Align(alignment: Alignment.topLeft, child: t),
    );
  }

  /// La impresora corta la línea al llegar al ancho (sin partir por palabras).
  static List<String> _partir(String texto, int cols) {
    if (texto.isEmpty) return [''];
    return [
      for (var i = 0; i < texto.length; i += cols)
        texto.substring(i, min(i + cols, texto.length)),
    ];
  }

  static String _alinear(String s, int cols, Alineacion a) => switch (a) {
        Alineacion.izquierda => s,
        Alineacion.centro => ' ' * ((cols - s.length) ~/ 2) + s,
        Alineacion.derecha => ' ' * (cols - s.length) + s,
      };

  List<String> _fila(FilaTicket f) {
    final anchos = <int>[];
    var usado = 0;
    for (var i = 0; i < f.columnas.length; i++) {
      final c = i == f.columnas.length - 1
          ? _cols - usado
          : (_cols * f.columnas[i].ancho / 12).floor();
      anchos.add(c);
      usado += c;
    }
    final partes = [
      for (var i = 0; i < f.columnas.length; i++)
        _partir(f.columnas[i].texto, anchos[i]),
    ];
    final total = partes.map((p) => p.length).reduce(max);
    return [
      for (var r = 0; r < total; r++)
        [
          for (var i = 0; i < f.columnas.length; i++)
            _alinear(r < partes[i].length ? partes[i][r] : '', anchos[i],
                    f.columnas[i].alineacion)
                .padRight(anchos[i]),
        ].join(),
    ];
  }
}

class _Corte extends StatelessWidget {
  final double ancho;
  const _Corte({required this.ancho});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const Icon(Icons.content_cut, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (_, c) => Text(
              '- ' * (c.maxWidth / 8).floor(),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ),
      ]),
    );
  }
}
