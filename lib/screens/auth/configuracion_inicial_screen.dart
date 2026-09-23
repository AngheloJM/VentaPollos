import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth/pin_hasher.dart';
import 'auth_gate.dart';

/// Primer uso: se crea el administrador. No existe una clave por defecto.
class ConfiguracionInicialScreen extends StatefulWidget {
  const ConfiguracionInicialScreen({super.key});

  @override
  State<ConfiguracionInicialScreen> createState() =>
      _ConfiguracionInicialScreenState();
}

class _ConfiguracionInicialScreenState
    extends State<ConfiguracionInicialScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _pin = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _pin.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await context
          .read<AuthProvider>()
          .crearAdministradorInicial(_nombre.text, _pin.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return FondoAcceso(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bienvenido',
                style: tema.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Cree la cuenta de administrador. Con ella podrá configurar '
              'productos, precios, usuarios e impresora.',
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: tema.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese un nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'PIN (4 a 8 dígitos)',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
              validator: (v) => PinHasher.validar(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmacion,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Confirmar PIN',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
              validator: (v) => v != _pin.text ? 'Los PIN no coinciden' : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Guarde el PIN en un lugar seguro: no se puede recuperar.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.error),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _crear,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Crear administrador'),
            ),
          ],
        ),
      ),
    );
  }
}
