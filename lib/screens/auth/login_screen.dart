import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import 'auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Usuario? _seleccionado;
  String _pin = '';
  String? _error;
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    final activos = context.read<AuthProvider>().activos;
    if (activos.length == 1) _seleccionado = activos.first;
  }

  void _tecla(String d) {
    if (_verificando || _pin.length >= 8) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _ingresar() async {
    if (_pin.length < 4 || _seleccionado == null) {
      setState(() => _error = 'Ingrese su PIN');
      return;
    }
    setState(() => _verificando = true);
    final error =
        await context.read<AuthProvider>().iniciarSesion(_seleccionado!, _pin);
    if (!mounted) return;
    setState(() {
      _verificando = false;
      _error = error;
      _pin = '';
    });
    if (error != null) HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return FondoAcceso(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _seleccionado == null
            ? _elegirUsuario(auth.activos)
            : _ingresarPin(auth.activos.length > 1),
      ),
    );
  }

  Widget _elegirUsuario(List<Usuario> usuarios) {
    final tema = Theme.of(context);
    return Column(
      key: const ValueKey('usuarios'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Quién eres?',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final u in usuarios)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _seleccionado = u;
                  _pin = '';
                  _error = null;
                }),
                child: SizedBox(
                  width: 100,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      _Avatar(usuario: u, radio: 28),
                      const SizedBox(height: 6),
                      Text(u.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.titleSmall),
                      Text(u.rol.etiqueta,
                          style: tema.textTheme.bodySmall
                              ?.copyWith(color: tema.colorScheme.outline)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _ingresarPin(bool puedeCambiar) {
    final tema = Theme.of(context);
    final u = _seleccionado!;
    return Column(
      key: ValueKey('pin-${u.id}'),
      children: [
        _Avatar(usuario: u, radio: 30),
        const SizedBox(height: 8),
        Text(u.nombre,
            style: tema.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (puedeCambiar)
          TextButton(
            onPressed: () => setState(() => _seleccionado = null),
            child: const Text('Cambiar usuario'),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < (_pin.length < 4 ? 4 : _pin.length); i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? tema.colorScheme.primary
                      : tema.colorScheme.surfaceContainerHighest,
                ),
              ),
          ],
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: _error == null
                ? null
                : Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.error)),
          ),
        ),
        _Teclado(
          onDigito: _tecla,
          onBorrar: _borrar,
          onAceptar: _ingresar,
          ocupado: _verificando,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final Usuario usuario;
  final double radio;
  const _Avatar({required this.usuario, required this.radio});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radio,
      backgroundColor:
          usuario.esAdmin ? esquema.primary : esquema.secondaryContainer,
      child: Text(
        usuario.inicial,
        style: TextStyle(
          fontSize: radio * 0.8,
          fontWeight: FontWeight.w700,
          color: usuario.esAdmin ? Colors.white : esquema.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _Teclado extends StatelessWidget {
  final ValueChanged<String> onDigito;
  final VoidCallback onBorrar;
  final VoidCallback onAceptar;
  final bool ocupado;

  const _Teclado({
    required this.onDigito,
    required this.onBorrar,
    required this.onAceptar,
    required this.ocupado,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget tecla(Widget hijo, VoidCallback? accion, {bool resaltada = false}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 72,
          height: 60,
          child: resaltada
              ? FilledButton(
                  onPressed: accion,
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  child: hijo)
              : FilledButton.tonal(
                  onPressed: accion,
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  child: hijo),
        ),
      );
    }

    Widget digito(String d) => tecla(
        Text(d,
            style: tema.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        ocupado ? null : () => onDigito(d));

    return Column(children: [
      for (final fila in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (final d in fila) digito(d)],
        ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        tecla(const Icon(Icons.backspace_outlined), ocupado ? null : onBorrar),
        digito('0'),
        tecla(
          ocupado
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_forward),
          ocupado ? null : onAceptar,
          resaltada: true,
        ),
      ]),
    ]);
  }
}
