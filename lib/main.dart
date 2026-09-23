import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'data/repositories/config_repository.dart';
import 'data/repositories/producto_repository.dart';
import 'data/repositories/usuario_repository.dart';
import 'data/repositories/venta_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/carrito_provider.dart';
import 'providers/catalogo_provider.dart';
import 'providers/impresora_provider.dart';
import 'providers/licencia_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'services/licencia/licencia_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  final productoRepo = ProductoRepository();
  final ventaRepo = VentaRepository();
  final configRepo = ConfigRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: ventaRepo),
        ChangeNotifierProvider(
          create: (_) =>
              LicenciaProvider(LicenciaService(configRepo))..cargar(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(UsuarioRepository())..cargar(),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogoProvider(productoRepo)..cargar(),
        ),
        ChangeNotifierProvider(create: (_) => CarritoProvider()),
        ChangeNotifierProvider(
          create: (_) => ImpresoraProvider(configRepo)..cargar(),
        ),
      ],
      child: const VentaPollosApp(),
    ),
  );
}

class VentaPollosApp extends StatelessWidget {
  const VentaPollosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Venta Pollos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      home: const AuthGate(),
    );
  }
}
