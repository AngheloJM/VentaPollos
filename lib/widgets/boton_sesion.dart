import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/carrito_provider.dart';

/// Avatar del usuario actual con opción de cerrar sesión.
class BotonSesion extends StatelessWidget {
  const BotonSesion({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.actual;
    if (usuario == null) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Sesión',
      offset: const Offset(0, 48),
      onSelected: (v) {
        if (v == 'salir') {
          context.read<CarritoProvider>().limpiar();
          auth.cerrarSesion();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(usuario.nombre),
            subtitle: Text(usuario.rol.etiqueta),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'salir',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor:
              usuario.esAdmin ? esquema.primary : esquema.secondaryContainer,
          child: Text(
            usuario.inicial,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  usuario.esAdmin ? Colors.white : esquema.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
