import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/venta_repository.dart';
import '../models/venta.dart';
import '../providers/auth_provider.dart';
import '../providers/impresora_provider.dart';
import '../utils/formato.dart';
import '../widgets/ticket_preview.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  DateTime _dia = DateTime.now();
  late Future<List<Venta>> _ventas = _cargar();

  Future<List<Venta>> _cargar() => context.read<VentaRepository>().delDia(_dia);

  void _recargar() => setState(() => _ventas = _cargar());

  Future<void> _elegirDia() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (elegido != null) {
      _dia = elegido;
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: [
          TextButton.icon(
            onPressed: _elegirDia,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(fechaLarga(_dia)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Venta>>(
        future: _ventas,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final ventas = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Resumen(ventas: ventas),
                const SizedBox(height: 16),
                if (ventas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Sin ventas este día')),
                  ),
                for (final v in ventas)
                  _VentaTile(venta: v, onCambio: _recargar),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final List<Venta> ventas;
  const _Resumen({required this.ventas});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final validas = ventas.where((v) => !v.anulada).toList();
    final total = validas.fold(0, (s, v) => s + v.total);
    final porMetodo = {
      for (final m in MetodoPago.values)
        m: validas
            .where((v) => v.metodoPago == m)
            .fold(0, (s, v) => s + v.total),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tema.colorScheme.primary, tema.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total del día'),
          Text(dinero(total),
              style: tema.textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${validas.length} ventas'),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 4, children: [
            for (final e in porMetodo.entries)
              Text('${e.key.etiqueta}: ${dinero(e.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _VentaTile extends StatelessWidget {
  final Venta venta;
  final VoidCallback onCambio;
  const _VentaTile({required this.venta, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tachado = venta.anulada
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: tema.colorScheme.primaryContainer,
          child: Text(venta.tipo.emoji),
        ),
        title: Text(
          '#${venta.id}  ${_titulo(venta)}',
          style: tachado,
        ),
        subtitle: Text(
          '${hora(venta.fecha)} · ${venta.unidades} ítems · ${venta.metodoPago.etiqueta}'
          '${venta.usuarioNombre != null ? ' · ${venta.usuarioNombre}' : ''}'
          '${venta.anulada ? ' · ANULADA' : ''}',
        ),
        trailing: Text(dinero(venta.total),
            style: tema.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)
                .merge(tachado)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in venta.items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${i.cantidad} x ${i.nombre}'),
              subtitle: (i.descripcion ?? i.nota) != null
                  ? Text(
                      [i.descripcion, i.nota].whereType<String>().join(' · '))
                  : null,
              trailing: Text(dinero(i.subtotal)),
            ),
          if (venta.nota != null)
            Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Nota: ${venta.nota}', style: tema.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilledButton.tonalIcon(
              onPressed: () => mostrarVistaPrevia(
                context,
                context
                    .read<ImpresoraProvider>()
                    .ticketsVenta(venta, recibo: true),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver ticket'),
            ),
            OutlinedButton.icon(
              onPressed: () => _imprimir(context, recibo: false),
              icon: const Icon(Icons.restaurant),
              label: const Text('Comanda'),
            ),
            OutlinedButton.icon(
              onPressed: () => _imprimir(context, recibo: true),
              icon: const Icon(Icons.receipt),
              label: const Text('Recibo'),
            ),
            if (!venta.anulada && context.read<AuthProvider>().esAdmin)
              TextButton.icon(
                onPressed: () => _anular(context),
                icon: const Icon(Icons.block),
                label: const Text('Anular'),
                style: TextButton.styleFrom(
                    foregroundColor: tema.colorScheme.error),
              ),
          ]),
        ],
      ),
    );
  }

  static String _titulo(Venta v) => switch ((v.tipo, v.referencia)) {
        (TipoPedido.mesa, final String r) => 'Mesa $r',
        (_, final String r) => r,
        (final t, null) => t.etiqueta,
      };

  Future<void> _imprimir(BuildContext context, {required bool recibo}) async {
    final messenger = ScaffoldMessenger.of(context);
    final impresora = context.read<ImpresoraProvider>();
    try {
      await imprimirOMostrar(
        context,
        impresora.ticketsVenta(venta, comanda: !recibo, recibo: recibo),
      );
      if (!impresora.config.esPantalla) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Enviado a impresora')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _anular(BuildContext context) async {
    final repo = context.read<VentaRepository>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Anular venta #${venta.id}?'),
        content: const Text(
            'La venta quedará registrada como anulada y no sumará al total.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anular')),
        ],
      ),
    );
    if (ok == true) {
      await repo.anular(venta.id!);
      onCambio();
    }
  }
}
