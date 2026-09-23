import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/licencia_provider.dart';
import '../home_screen.dart';
import 'activacion_screen.dart';
import 'configuracion_inicial_screen.dart';
import 'login_screen.dart';

/// Decide qué mostrar según el estado de la sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final licencia = context.watch<LicenciaProvider>();
    final auth = context.watch<AuthProvider>();
    if (licencia.estado == EstadoLicencia.cargando || auth.cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Sin licencia vigente no se puede usar la app (los datos se conservan).
    if (!licencia.activa) return const ActivacionScreen();
    if (auth.requiereConfiguracion) return const ConfiguracionInicialScreen();
    final usuario = auth.actual;
    if (usuario == null) return const LoginScreen();
    // La clave reinicia la navegación al cambiar de usuario.
    return HomeScreen(key: ValueKey(usuario.id));
  }
}

/// Fondo con degradado usado por las pantallas de acceso.
class FondoAcceso extends StatelessWidget {
  final Widget child;
  const FondoAcceso({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tema.colorScheme.primary, tema.colorScheme.secondary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  const Text('🍗', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 4),
                  Text('Venta Pollos',
                      style: tema.textTheme.headlineMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: child,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
