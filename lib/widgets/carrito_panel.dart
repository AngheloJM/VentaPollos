import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/venta_repository.dart';
import '../models/venta.dart';
import '../providers/carrito_provider.dart';
import '../providers/impresora_provider.dart';
import '../utils/formato.dart';

class CarritoPanel extends StatefulWidget {
  /// En teléfono el panel vive en un bottom sheet que se cierra al cobrar.
  final bool cerrarAlCobrar;
  const CarritoPanel({super.key, this.cerrarAlCobrar = false});

  @override
  State<CarritoPanel> createState() => _CarritoPanelState();
}

class _CarritoPanelState extends State<CarritoPanel> {
  late final CarritoProvider _carrito = context.read<CarritoProvider>();
  late final _referencia = TextEditingController(text: _carrito.referencia);
  late final _nota = TextEditingController(text: _carrito.nota);
  bool _procesando = false;

  @override
  void dispose() {
    _referencia.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();
    final tema = Theme.of(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        child: Row(children: [
          Text('Pedido actual',
              style: tema.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (!carrito.vacio)
            TextButton.icon(
              onPressed: _limpiar,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Vaciar'),
            ),
        ]),
      ),
      Expanded(
        child: carrito.vacio
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🛒', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('Toca un producto para agregarlo',
                      style: tema.textTheme.bodyMedium
                          ?.copyWith(color: tema.colorScheme.outline)),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final l in carrito.lineas) _LineaTile(linea: l),
                  const SizedBox(height: 12),
                  _opciones(carrito, tema),
                ],
              ),
      ),
      _resumen(carrito, tema),
    ]);
  }

  Widget _opciones(CarritoProvider carrito, ThemeData tema) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<TipoPedido>(
        segments: [
          for (final t in TipoPedido.values)
            ButtonSegment(value: t, label: Text('${t.emoji} ${t.etiqueta}')),
        ],
        selected: {carrito.tipo},
        showSelectedIcon: false,
        onSelectionChanged: (s) => carrito.setTipo(s.first),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _referencia,
        onChanged: (v) => carrito.referencia = v,
        decoration: InputDecoration(
          labelText: carrito.tipo == TipoPedido.mesa
              ? 'Número de mesa'
              : 'Nombre del cliente',
          prefixIcon: Icon(carrito.tipo == TipoPedido.mesa
              ? Icons.table_restaurant_outlined
              : Icons.person_outline),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _nota,
        onChanged: (v) => carrito.nota = v,
        decoration: const InputDecoration(
          labelText: 'Nota para cocina',
          prefixIcon: Icon(Icons.sticky_note_2_outlined),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final m in MetodoPago.values)
          ChoiceChip(
            label: Text(m.etiqueta),
            selected: carrito.metodoPago == m,
            onSelected: (_) => carrito.setMetodoPago(m),
          ),
      ]),
      const SizedBox(height: 12),
    ]);
  }

  Widget _resumen(CarritoProvider carrito, ThemeData tema) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: tema.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Row(children: [
            Text('Total', style: tema.textTheme.titleMedium),
            const Spacer(),
            Text(dinero(carrito.total),
                style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tema.colorScheme.primary)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: carrito.vacio || _procesando ? null : _cobrar,
              icon: _procesando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print_outlined),
              label: const Text('Cobrar e imprimir comanda'),
            ),
          ),
        ]),
      ),
    );
  }

  void _limpiar() {
    _carrito.limpiar();
    _referencia.clear();
    _nota.clear();
  }

  Future<void> _cobrar() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ventas = context.read<VentaRepository>();
    final impresora = context.read<ImpresoraProvider>();

    setState(() => _procesando = true);
    try {
      // Primero se persiste: si la impresión falla, la venta no se pierde.
      final venta = await ventas.registrar(_carrito.aVenta());
      _limpiar();
      if (widget.cerrarAlCobrar) navigator.pop();

      String mensaje = 'Venta #${venta.id} registrada · ${dinero(venta.total)}';
      if (impresora.config.configurada) {
        try {
          await impresora.imprimirVenta(venta);
          mensaje += ' · Comanda impresa';
        } catch (e) {
          mensaje += ' · No se imprimió: $e';
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Error al registrar la venta: $e')));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }
}

class _LineaTile extends StatelessWidget {
  final LineaCarrito linea;
  const _LineaTile({required this.linea});

  @override
  Widget build(BuildContext context) {
    final carrito = context.read<CarritoProvider>();
    final tema = Theme.of(context);

    return Dismissible(
      key: ObjectKey(linea),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => carrito.quitar(linea),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: tema.colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(linea.producto.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _editarNota(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(linea.producto.nombre,
                      style: tema.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    linea.nota ?? dinero(linea.subtotal),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: linea.nota != null
                          ? tema.colorScheme.tertiary
                          : tema.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed: () => carrito.cambiarCantidad(linea, -1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 32,
            child: Text('${linea.cantidad}',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton.filled(
            visualDensity: VisualDensity.compact,
            onPressed: () => carrito.cambiarCantidad(linea, 1),
            icon: const Icon(Icons.add),
          ),
        ]),
      ),
    );
  }

  Future<void> _editarNota(BuildContext context) async {
    final carrito = context.read<CarritoProvider>();
    final ctrl = TextEditingController(text: linea.nota);
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nota: ${linea.producto.nombre}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: pierna, sin ají'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if (texto != null) carrito.ponerNota(linea, texto);
  }
}
