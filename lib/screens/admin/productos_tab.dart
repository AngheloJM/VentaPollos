import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/producto.dart';
import '../../providers/catalogo_provider.dart';
import '../../utils/formato.dart';

const emojisDisponibles = [
  '🍗', '🍖', '🐔', '🍱', '🥡', '🍟', '🍚', '🥗', '🌽', '🥔', //
  '🍝', '🌭', '🍔', '🥤', '🧃', '🍺', '💧', '☕', '🍰', '🍦',
];

class ProductosTab extends StatefulWidget {
  const ProductosTab({super.key});

  @override
  State<ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<ProductosTab> {
  int? _categoriaId;

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    final tema = Theme.of(context);
    final categorias = _categoriaId == null
        ? catalogo.categorias
        : catalogo.categorias.where((c) => c.id == _categoriaId).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: catalogo.categorias.isEmpty
            ? null
            : () => editarProducto(context, null, categoriaId: _categoriaId),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: _categoriaId == null,
                  onSelected: (_) => setState(() => _categoriaId = null),
                ),
              ),
              for (final c in catalogo.categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Text(c.emoji),
                    label: Text(c.nombre),
                    selected: _categoriaId == c.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _categoriaId = c.id),
                  ),
                ),
            ]),
          ),
          if (catalogo.categorias.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: Text(
                      'Primero cree una categoría en la pestaña Categorías')),
            ),
          for (final c in categorias) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('${c.emoji}  ${c.nombre}',
                  style: tema.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final p
                in catalogo.productos.where((p) => p.categoriaId == c.id))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(p.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(p.nombre,
                      style: TextStyle(
                          color: p.activo ? null : tema.colorScheme.outline)),
                  subtitle: Text(
                    [
                      p.activo ? dinero(p.precio) : 'Inactivo',
                      if (p.descripcion?.isNotEmpty ?? false) p.descripcion!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Switch(
                    value: p.activo,
                    onChanged: (v) => catalogo.guardar(p.copyWith(activo: v)),
                  ),
                  onTap: () => editarProducto(context, p),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Future<void> editarProducto(BuildContext context, Producto? producto,
    {int? categoriaId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        _FormProducto(producto: producto, categoriaInicial: categoriaId),
  );
}

class _FormProducto extends StatefulWidget {
  final Producto? producto;
  final int? categoriaInicial;
  const _FormProducto({this.producto, this.categoriaInicial});

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _descripcion =
      TextEditingController(text: widget.producto?.descripcion);
  late final _precio = TextEditingController(
      text: widget.producto == null
          ? ''
          : (widget.producto!.precio / 100).toStringAsFixed(2));
  late String _emoji = widget.producto?.emoji ?? '🍗';
  late int? _categoriaId =
      widget.producto?.categoriaId ?? widget.categoriaInicial;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.read<CatalogoProvider>();
    final esNuevo = widget.producto == null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(esNuevo ? 'Nuevo plato o combo' : 'Editar producto',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in emojisDisponibles)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  selected: _emoji == e,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese un nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              decoration: const InputDecoration(
                labelText: 'Contenido / descripción (opcional)',
                hintText: 'Ej: 1/4 pollo + papas + gaseosa',
                helperText: 'Se imprime en la comanda para cocina',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precio,
              decoration: const InputDecoration(
                  labelText: 'Precio', prefixText: '$moneda '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  parsearDinero(v ?? '') == null ? 'Precio inválido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _categoriaId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in catalogo.categorias)
                  DropdownMenuItem(
                      value: c.id, child: Text('${c.emoji}  ${c.nombre}')),
              ],
              onChanged: (v) => setState(() => _categoriaId = v),
              validator: (v) => v == null ? 'Seleccione una categoría' : null,
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (!esNuevo)
                TextButton.icon(
                  onPressed: () => _eliminar(catalogo),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => _guardar(catalogo),
                child: const Text('Guardar'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar(CatalogoProvider catalogo) async {
    if (!_form.currentState!.validate()) return;
    final descripcion = _descripcion.text.trim();
    await catalogo.guardar(Producto(
      id: widget.producto?.id,
      categoriaId: _categoriaId!,
      nombre: _nombre.text.trim(),
      descripcion: descripcion.isEmpty ? null : descripcion,
      precio: parsearDinero(_precio.text)!,
      emoji: _emoji,
      activo: widget.producto?.activo ?? true,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _eliminar(CatalogoProvider catalogo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "${widget.producto!.nombre}"?'),
        content: const Text(
            'El historial de ventas se conserva. Si solo quiere ocultarlo, desactívelo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await catalogo.eliminar(widget.producto!);
    if (mounted) Navigator.pop(context);
  }
}
