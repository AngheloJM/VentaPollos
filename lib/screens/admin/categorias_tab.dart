import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/producto.dart';
import '../../providers/catalogo_provider.dart';
import 'productos_tab.dart';

class CategoriasTab extends StatelessWidget {
  const CategoriasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: catalogo.categorias.isEmpty
          ? const Center(child: Text('Sin categorías'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final c in catalogo.categorias)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading:
                          Text(c.emoji, style: const TextStyle(fontSize: 28)),
                      title: Text(c.nombre),
                      subtitle: Text(
                          '${catalogo.productos.where((p) => p.categoriaId == c.id).length} productos · orden ${c.orden}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editar(context, c),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _editar(BuildContext context, Categoria? categoria) async {
    final catalogo = context.read<CatalogoProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final resultado = await showDialog<_ResultadoCategoria>(
      context: context,
      builder: (_) => _DialogoCategoria(
        categoria: categoria,
        ordenSugerido: catalogo.categorias.length,
      ),
    );
    if (resultado == null) return;
    try {
      if (resultado.eliminar) {
        await catalogo.eliminarCategoria(categoria!);
      } else {
        await catalogo.guardarCategoria(resultado.categoria!);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _ResultadoCategoria {
  final Categoria? categoria;
  final bool eliminar;
  const _ResultadoCategoria.guardar(this.categoria) : eliminar = false;
  const _ResultadoCategoria.eliminar()
      : categoria = null,
        eliminar = true;
}

class _DialogoCategoria extends StatefulWidget {
  final Categoria? categoria;
  final int ordenSugerido;
  const _DialogoCategoria({this.categoria, required this.ordenSugerido});

  @override
  State<_DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends State<_DialogoCategoria> {
  late final _nombre = TextEditingController(text: widget.categoria?.nombre);
  late final _orden = TextEditingController(
      text: '${widget.categoria?.orden ?? widget.ordenSugerido}');
  late String _emoji = widget.categoria?.emoji ?? '🍗';

  @override
  void dispose() {
    _nombre.dispose();
    _orden.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return;
    final base = widget.categoria ?? const Categoria(nombre: '');
    Navigator.pop(
      context,
      _ResultadoCategoria.guardar(base.copyWith(
        nombre: nombre,
        emoji: _emoji,
        orden: int.tryParse(_orden.text) ?? base.orden,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esNueva = widget.categoria == null;
    return AlertDialog(
      title: Text(esNueva ? 'Nueva categoría' : 'Editar categoría'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final e in emojisDisponibles)
              ChoiceChip(
                label: Text(e, style: const TextStyle(fontSize: 18)),
                selected: _emoji == e,
                showCheckmark: false,
                onSelected: (_) => setState(() => _emoji = e),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _nombre,
            autofocus: esNueva,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _orden,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Orden (menor aparece primero)'),
          ),
        ]),
      ),
      actions: [
        if (!esNueva)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _ResultadoCategoria.eliminar()),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
