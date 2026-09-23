import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/carrito_provider.dart';
import '../providers/catalogo_provider.dart';
import '../utils/formato.dart';
import '../widgets/carrito_panel.dart';
import '../widgets/producto_card.dart';

class VentaScreen extends StatefulWidget {
  const VentaScreen({super.key});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  int? _categoriaId;

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();

    return LayoutBuilder(builder: (context, c) {
      final tablet = c.maxWidth >= 800;
      final catalogoView = _Catalogo(
        catalogo: catalogo,
        categoriaId: _categoriaId,
        onCategoria: (id) => setState(() => _categoriaId = id),
      );

      if (tablet) {
        return SafeArea(
          child: Row(children: [
            Expanded(child: catalogoView),
            const SizedBox(
              width: 380,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Card(child: CarritoPanel()),
              ),
            ),
          ]),
        );
      }

      return Scaffold(
        body: SafeArea(child: catalogoView),
        bottomNavigationBar: const _BarraCarrito(),
      );
    });
  }
}

class _Catalogo extends StatelessWidget {
  final CatalogoProvider catalogo;
  final int? categoriaId;
  final ValueChanged<int?> onCategoria;

  const _Catalogo({
    required this.catalogo,
    required this.categoriaId,
    required this.onCategoria,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (catalogo.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final productos = catalogo.activosDe(categoriaId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  tema.colorScheme.primary,
                  tema.colorScheme.secondary,
                ]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🍗', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva venta',
                    style: tema.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(fechaLarga(DateTime.now()),
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: tema.colorScheme.outline)),
              ],
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _chip(context, 'Todo', '✨', null),
            for (final c in catalogo.categorias)
              _chip(context, c.nombre, c.emoji, c.id),
          ]),
        ),
        Expanded(
          child: productos.isEmpty
              ? const Center(child: Text('No hay productos en esta categoría'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: productos.length,
                  itemBuilder: (_, i) => ProductoCard(producto: productos[i]),
                ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String texto, String emoji, int? id) {
    final seleccionado = categoriaId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Text(emoji),
        label: Text(texto),
        selected: seleccionado,
        showCheckmark: false,
        onSelected: (_) => onCategoria(id),
      ),
    );
  }
}

/// Barra inferior en teléfonos: resume el carrito y abre el detalle.
class _BarraCarrito extends StatelessWidget {
  const _BarraCarrito();

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();
    final tema = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: carrito.vacio
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Material(
                color: tema.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _abrirCarrito(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Text('${carrito.unidades}',
                            style: TextStyle(
                                color: tema.colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text('Ver pedido',
                          style: tema.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(dinero(carrito.total),
                          style: tema.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }

  void _abrirCarrito(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, __) => const CarritoPanel(cerrarAlCobrar: true),
      ),
    );
  }
}
