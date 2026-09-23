import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';

import '../../models/printer_config.dart';
import '../../providers/impresora_provider.dart';
import '../../services/printing/printer_transport.dart';
import '../../widgets/ticket_preview.dart';

class ImpresoraTab extends StatefulWidget {
  const ImpresoraTab({super.key});

  @override
  State<ImpresoraTab> createState() => _ImpresoraTabState();
}

class _ImpresoraTabState extends State<ImpresoraTab> {
  late final ImpresoraProvider _impresora = context.read<ImpresoraProvider>();
  late PrinterConfig _cfg = _impresora.config;
  late final _negocio = TextEditingController(text: _cfg.nombreNegocio);
  late final _ip = TextEditingController(text: _cfg.ip);
  late final _puerto = TextEditingController(text: '${_cfg.puerto}');

  List<BluetoothInfo> _dispositivos = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    // La configuración se carga de forma asíncrona al iniciar la app.
    if (!_impresora.cargado) _impresora.addListener(_sincronizar);
  }

  void _sincronizar() {
    if (!_impresora.cargado) return;
    _impresora.removeListener(_sincronizar);
    final c = _impresora.config;
    setState(() {
      _cfg = c;
      _negocio.text = c.nombreNegocio;
      _ip.text = c.ip;
      _puerto.text = '${c.puerto}';
    });
  }

  @override
  void dispose() {
    _impresora.removeListener(_sincronizar);
    _negocio.dispose();
    _ip.dispose();
    _puerto.dispose();
    super.dispose();
  }

  PrinterConfig get _formulario => _cfg.copyWith(
        nombreNegocio: _negocio.text.trim(),
        ip: _ip.text.trim(),
        puerto: int.tryParse(_puerto.text.trim()) ?? 9100,
      );

  Future<void> _buscarBluetooth() async {
    setState(() => _buscando = true);
    try {
      if (!await BluetoothTransport.permisosConcedidos()) {
        _aviso('Conceda el permiso de Bluetooth / dispositivos cercanos');
      }
      final lista = await BluetoothTransport.vinculadas();
      setState(() => _dispositivos = lista);
      if (lista.isEmpty) {
        _aviso(
            'No hay impresoras vinculadas. Vincúlela primero en los ajustes del teléfono.');
      }
    } catch (e) {
      _aviso('Error buscando dispositivos: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _guardar() async {
    await _impresora.guardar(_formulario);
    _aviso('Configuración guardada');
  }

  Future<void> _probar() async {
    final cfg = _formulario;
    try {
      await _impresora.imprimir([_impresora.ticketPrueba(cfg)], cfg);
      _aviso('Prueba enviada');
    } catch (e) {
      _aviso('$e');
    }
  }

  void _vistaPrevia() {
    final cfg = _formulario;
    mostrarVistaPrevia(context, [_impresora.ticketPrueba(cfg)],
        anchoPapel: cfg.anchoPapel);
  }

  void _aviso(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final imprimiendo = context.watch<ImpresoraProvider>().imprimiendo;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Seccion(
            titulo: 'Negocio',
            icono: Icons.storefront_outlined,
            children: [
              TextField(
                controller: _negocio,
                decoration:
                    const InputDecoration(labelText: 'Nombre en el recibo'),
              ),
            ],
          ),
          _Seccion(
            titulo: 'Impresora térmica',
            icono: Icons.print_outlined,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (tipo, icono) in const [
                  (TipoConexion.ninguna, Icons.print_disabled_outlined),
                  (TipoConexion.pantalla, Icons.visibility_outlined),
                  (TipoConexion.red, Icons.wifi),
                  (TipoConexion.bluetooth, Icons.bluetooth),
                ])
                  ChoiceChip(
                    avatar: Icon(icono, size: 18),
                    label: Text(tipo.etiqueta),
                    selected: _cfg.conexion == tipo,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _cfg = _cfg.copyWith(conexion: tipo)),
                  ),
              ]),
              if (_cfg.esPantalla)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Modo prueba: al cobrar se muestra la comanda en pantalla '
                    'tal como saldría impresa, sin enviarla a ninguna impresora.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),
              if (_cfg.conexion == TipoConexion.red) ...[
                TextField(
                  controller: _ip,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Dirección IP',
                    hintText: '192.168.1.100',
                    prefixIcon: Icon(Icons.lan_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _puerto,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
              ],
              if (_cfg.conexion == TipoConexion.bluetooth) ...[
                if (_cfg.bluetoothMac.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bluetooth_connected),
                    title: Text(_cfg.bluetoothNombre),
                    subtitle: Text(_cfg.bluetoothMac),
                  ),
                OutlinedButton.icon(
                  onPressed: _buscando ? null : _buscarBluetooth,
                  icon: _buscando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: const Text('Buscar impresoras vinculadas'),
                ),
                RadioGroup<String>(
                  groupValue: _cfg.bluetoothMac,
                  onChanged: (mac) {
                    final d =
                        _dispositivos.firstWhere((x) => x.macAdress == mac);
                    setState(() => _cfg = _cfg.copyWith(
                        bluetoothMac: d.macAdress, bluetoothNombre: d.name));
                  },
                  child: Column(children: [
                    for (final d in _dispositivos)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: d.macAdress,
                        title: Text(d.name),
                        subtitle: Text(d.macAdress),
                      ),
                  ]),
                ),
              ],
              if (_cfg.conexion != TipoConexion.ninguna) ...[
                const SizedBox(height: 16),
                Text('Ancho de papel', style: tema.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 58, label: Text('58 mm')),
                    ButtonSegment(value: 80, label: Text('80 mm')),
                  ],
                  selected: {_cfg.anchoPapel},
                  onSelectionChanged: (s) =>
                      setState(() => _cfg = _cfg.copyWith(anchoPapel: s.first)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Imprimir también recibo del cliente'),
                  subtitle: const Text('Además de la comanda de cocina'),
                  value: _cfg.imprimirRecibo,
                  onChanged: (v) =>
                      setState(() => _cfg = _cfg.copyWith(imprimirRecibo: v)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _vistaPrevia,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Vista previa'),
                    ),
                  ),
                  if (!_cfg.esPantalla) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: imprimiendo ? null : _probar,
                        icon: const Icon(Icons.receipt_outlined),
                        label: const Text('Imprimir prueba'),
                      ),
                    ),
                  ],
                ]),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar configuración'),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> children;
  const _Seccion(
      {required this.titulo, required this.icono, required this.children});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icono, color: tema.colorScheme.primary),
            const SizedBox(width: 8),
            Text(titulo,
                style: tema.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ]),
      ),
    );
  }
}
