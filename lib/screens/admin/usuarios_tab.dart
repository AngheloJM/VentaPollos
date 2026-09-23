import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth/pin_hasher.dart';

class UsuariosTab extends StatelessWidget {
  const UsuariosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tema = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formulario(context, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo usuario'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          for (final u in auth.usuarios)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: u.esAdmin
                      ? tema.colorScheme.primary
                      : tema.colorScheme.secondaryContainer,
                  child: Text(u.inicial,
                      style: TextStyle(
                          color: u.esAdmin ? Colors.white : null,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text(
                  u.id == auth.actual?.id ? '${u.nombre} (tú)' : u.nombre,
                  style: TextStyle(
                      color: u.activo ? null : tema.colorScheme.outline),
                ),
                subtitle: Text(u.activo ? u.rol.etiqueta : 'Desactivado'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _formulario(context, u),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _formulario(BuildContext context, Usuario? usuario) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _FormUsuario(usuario: usuario),
    );
  }
}

class _FormUsuario extends StatefulWidget {
  final Usuario? usuario;
  const _FormUsuario({this.usuario});

  @override
  State<_FormUsuario> createState() => _FormUsuarioState();
}

class _FormUsuarioState extends State<_FormUsuario> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.usuario?.nombre);
  final _pin = TextEditingController();
  late Rol _rol = widget.usuario?.rol ?? Rol.cajero;
  late bool _activo = widget.usuario?.activo ?? true;
  bool _guardando = false;

  bool get _esNuevo => widget.usuario == null;

  @override
  void dispose() {
    _nombre.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      if (_esNuevo) {
        await auth.crearUsuario(_nombre.text, _rol, _pin.text);
      } else {
        await auth.actualizarUsuario(widget.usuario!.copyWith(
          nombre: _nombre.text.trim(),
          rol: _rol,
          activo: _activo,
        ));
        if (_pin.text.isNotEmpty) {
          await auth.cambiarPin(widget.usuario!, _pin.text);
        }
      }
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Usuario guardado')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_esNuevo ? 'Nuevo usuario' : 'Editar usuario',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese un nombre' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<Rol>(
              segments: const [
                ButtonSegment(
                    value: Rol.cajero,
                    icon: Icon(Icons.point_of_sale),
                    label: Text('Cajero')),
                ButtonSegment(
                    value: Rol.admin,
                    icon: Icon(Icons.admin_panel_settings),
                    label: Text('Administrador')),
              ],
              selected: {_rol},
              onSelectionChanged: (s) => setState(() => _rol = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _rol == Rol.admin
                  ? 'Acceso total: productos, precios, usuarios, impresora y anulaciones.'
                  : 'Puede vender, ver ventas e imprimir. No modifica configuración.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(
                labelText:
                    _esNuevo ? 'PIN (4 a 8 dígitos)' : 'Nuevo PIN (opcional)',
                counterText: '',
              ),
              validator: (v) {
                if (!_esNuevo && (v == null || v.isEmpty)) return null;
                return PinHasher.validar(v ?? '');
              },
            ),
            if (!_esNuevo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usuario activo'),
                subtitle:
                    const Text('Los usuarios inactivos no pueden ingresar'),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
