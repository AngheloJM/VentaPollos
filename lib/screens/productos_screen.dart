import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../providers/catalogo_provider.dart';
import '../utils/formato.dart';

class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          for (final c in catalogo.categorias) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('${c.emoji}  ${c.nombre}',
                  style: tema.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final p in catalogo.productos.where((p) => p.categoriaId == c.id))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(p.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(p.nombre,
                      style: TextStyle(
                          color: p.activo ? null : tema.colorScheme.outline)),
                  subtitle: Text(p.activo ? dinero(p.precio) : 'Inactivo'),
                  trailing: Switch(
                    value: p.activo,
                    onChanged: (v) => catalogo.guardar(p.copyWith(activo: v)),
                  ),
                  onTap: () => _editar(context, p),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _editar(BuildContext context, Producto? producto) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FormProducto(producto: producto),
    );
  }
}

class _FormProducto extends StatefulWidget {
  final Producto? producto;
  const _FormProducto({this.producto});

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _precio = TextEditingController(
      text: widget.producto == null
          ? ''
          : (widget.producto!.precio / 100).toStringAsFixed(2));
  late String _emoji = widget.producto?.emoji ?? '🍗';
  late int? _categoriaId = widget.producto?.categoriaId;

  static const _emojis = ['🍗', '🍖', '🐔', '🍱', '🍟', '🍚', '🥗', '🌽', '🥤', '🧃', '🍺', '🍰'];

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.read<CatalogoProvider>();
    final esNuevo = widget.producto == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(esNuevo ? 'Nuevo producto' : 'Editar producto',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _emojis)
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
    final base = widget.producto ??
        Producto(categoriaId: _categoriaId!, nombre: '', precio: 0);
    await catalogo.guardar(base.copyWith(
      nombre: _nombre.text.trim(),
      precio: parsearDinero(_precio.text),
      emoji: _emoji,
      categoriaId: _categoriaId,
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
