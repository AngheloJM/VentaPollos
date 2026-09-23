import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/licencia_provider.dart';
import '../../utils/formato.dart';
import 'auth_gate.dart';

/// Se muestra al primer inicio o cuando la licencia (beta) venció.
class ActivacionScreen extends StatefulWidget {
  const ActivacionScreen({super.key});

  @override
  State<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends State<ActivacionScreen> {
  final _clave = TextEditingController();
  late final Future<String> _idEquipo =
      context.read<LicenciaProvider>().idEquipo();
  bool _activando = false;
  String? _error;

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  Future<void> _activar() async {
    if (_clave.text.length != FormatoClave.largo) {
      setState(() => _error = 'Complete la clave de licencia');
      return;
    }
    setState(() {
      _activando = true;
      _error = null;
    });
    try {
      await context.read<LicenciaProvider>().activar('VP-${_clave.text}');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final licencia = context.watch<LicenciaProvider>();
    final expirada = licencia.estado == EstadoLicencia.expirada;

    return FondoAcceso(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(expirada ? Icons.lock_clock_outlined : Icons.key_outlined,
              size: 40, color: tema.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            expirada ? 'Su licencia venció' : 'Activar la aplicación',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            expirada
                ? 'La licencia ${licencia.licencia!.esBeta ? 'beta ' : ''}'
                    'venció el ${fechaHora(licencia.licencia!.expira!.toLocal())}. '
                    'Ingrese una licencia nueva para continuar; '
                    'sus productos y ventas se conservan.'
                : 'Ingrese la clave de licencia que le entregó su proveedor. '
                    'Solo se necesita internet para este paso.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium
                ?.copyWith(color: tema.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _clave,
            enabled: !_activando,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FormatoClave()],
            textAlign: TextAlign.center,
            style: tema.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixText: 'VP-',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _activar(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _activando ? null : _activar,
            icon: _activando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined),
            label: Text(_activando ? 'Activando…' : 'Activar'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _idEquipo,
            builder: (_, snap) => Text(
              snap.hasData ? 'ID de este equipo: ${snap.data}' : '',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Da forma a los 16 caracteres de la clave: XXXX-XXXX-XXXX-XXXX.
/// El prefijo "VP-" es fijo en el campo; si se pega la clave completa,
/// se quita el "VP" inicial.
class FormatoClave extends TextInputFormatter {
  static const largo = 19;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    var crudo = nuevo.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (crudo.length > 16 && crudo.startsWith('VP')) crudo = crudo.substring(2);
    if (crudo.length > 16) crudo = crudo.substring(0, 16);
    final texto = [
      for (var i = 0; i < crudo.length; i += 4)
        crudo.substring(i, i + 4 > crudo.length ? crudo.length : i + 4),
    ].join('-');
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
