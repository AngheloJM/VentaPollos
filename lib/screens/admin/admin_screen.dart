import 'package:flutter/material.dart';

import '../../widgets/boton_sesion.dart';
import 'categorias_tab.dart';
import 'impresora_tab.dart';
import 'productos_tab.dart';
import 'usuarios_tab.dart';

/// Panel de administración: solo visible para usuarios con rol admin.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          actions: const [BotonSesion(), SizedBox(width: 8)],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Platos y combos'),
              Tab(icon: Icon(Icons.category_outlined), text: 'Categorías'),
              Tab(icon: Icon(Icons.group_outlined), text: 'Usuarios'),
              Tab(icon: Icon(Icons.print_outlined), text: 'Impresora'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          ProductosTab(),
          CategoriasTab(),
          UsuariosTab(),
          ImpresoraTab(),
        ]),
      ),
    );
  }
}
