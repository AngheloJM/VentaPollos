import 'dart:io';

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../models/printer_config.dart';

class ImpresionException implements Exception {
  final String mensaje;
  ImpresionException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Canal físico hacia la impresora.
abstract class PrinterTransport {
  Future<void> enviar(List<int> bytes);

  factory PrinterTransport.desde(PrinterConfig c) => switch (c.conexion) {
        TipoConexion.red => RedTransport(c.ip, c.puerto),
        TipoConexion.bluetooth => BluetoothTransport(c.bluetoothMac),
        TipoConexion.ninguna =>
          throw ImpresionException('No hay impresora configurada'),
      };
}

/// Impresoras de red (Ethernet / WiFi) en modo RAW, normalmente puerto 9100.
class RedTransport implements PrinterTransport {
  final String ip;
  final int puerto;
  RedTransport(this.ip, this.puerto);

  @override
  Future<void> enviar(List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, puerto,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
    } on SocketException catch (e) {
      throw ImpresionException(
          'No se pudo conectar a $ip:$puerto (${e.osError?.message ?? e.message})');
    } finally {
      await socket?.close();
    }
  }
}

/// Impresoras Bluetooth (clásico en Android, BLE en iOS).
class BluetoothTransport implements PrinterTransport {
  final String mac;
  BluetoothTransport(this.mac);

  @override
  Future<void> enviar(List<int> bytes) async {
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw ImpresionException('Bluetooth desactivado');
    }
    if (!await PrintBluetoothThermal.connectionStatus) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!ok) throw ImpresionException('No se pudo conectar a la impresora');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) throw ImpresionException('Error al enviar datos por Bluetooth');
  }

  static Future<List<BluetoothInfo>> vinculadas() =>
      PrintBluetoothThermal.pairedBluetooths;

  static Future<bool> permisosConcedidos() =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  static Future<void> desconectar() => PrintBluetoothThermal.disconnect;
}
