enum TipoConexion {
  ninguna('Ninguna'),

  /// Sin impresora física: muestra el ticket en pantalla.
  pantalla('Pantalla'),
  red('Red'),
  bluetooth('Bluetooth');

  const TipoConexion(this.etiqueta);
  final String etiqueta;
}

class PrinterConfig {
  final TipoConexion conexion;
  final String ip;
  final int puerto;
  final String bluetoothMac;
  final String bluetoothNombre;

  /// 58 u 80 mm.
  final int anchoPapel;
  final String nombreNegocio;
  final bool imprimirRecibo;

  const PrinterConfig({
    this.conexion = TipoConexion.ninguna,
    this.ip = '',
    this.puerto = 9100,
    this.bluetoothMac = '',
    this.bluetoothNombre = '',
    this.anchoPapel = 80,
    this.nombreNegocio = 'Pollería',
    this.imprimirRecibo = false,
  });

  bool get configurada => switch (conexion) {
        TipoConexion.ninguna => false,
        TipoConexion.pantalla => true,
        TipoConexion.red => ip.isNotEmpty,
        TipoConexion.bluetooth => bluetoothMac.isNotEmpty,
      };

  bool get esPantalla => conexion == TipoConexion.pantalla;

  String get descripcion => switch (conexion) {
        TipoConexion.ninguna => 'Sin impresora',
        TipoConexion.pantalla => 'Vista previa en pantalla',
        TipoConexion.red => 'Red · $ip:$puerto',
        TipoConexion.bluetooth => 'Bluetooth · $bluetoothNombre',
      };

  Map<String, String> toMap() => {
        'imp_conexion': conexion.name,
        'imp_ip': ip,
        'imp_puerto': '$puerto',
        'imp_bt_mac': bluetoothMac,
        'imp_bt_nombre': bluetoothNombre,
        'imp_ancho': '$anchoPapel',
        'negocio_nombre': nombreNegocio,
        'imp_recibo': imprimirRecibo ? '1' : '0',
      };

  factory PrinterConfig.fromMap(Map<String, String> m) {
    const d = PrinterConfig();
    return PrinterConfig(
      conexion:
          TipoConexion.values.asNameMap()[m['imp_conexion']] ?? d.conexion,
      ip: m['imp_ip'] ?? d.ip,
      puerto: int.tryParse(m['imp_puerto'] ?? '') ?? d.puerto,
      bluetoothMac: m['imp_bt_mac'] ?? d.bluetoothMac,
      bluetoothNombre: m['imp_bt_nombre'] ?? d.bluetoothNombre,
      anchoPapel: int.tryParse(m['imp_ancho'] ?? '') ?? d.anchoPapel,
      nombreNegocio: m['negocio_nombre'] ?? d.nombreNegocio,
      imprimirRecibo: m['imp_recibo'] == '1',
    );
  }

  PrinterConfig copyWith({
    TipoConexion? conexion,
    String? ip,
    int? puerto,
    String? bluetoothMac,
    String? bluetoothNombre,
    int? anchoPapel,
    String? nombreNegocio,
    bool? imprimirRecibo,
  }) =>
      PrinterConfig(
        conexion: conexion ?? this.conexion,
        ip: ip ?? this.ip,
        puerto: puerto ?? this.puerto,
        bluetoothMac: bluetoothMac ?? this.bluetoothMac,
        bluetoothNombre: bluetoothNombre ?? this.bluetoothNombre,
        anchoPapel: anchoPapel ?? this.anchoPapel,
        nombreNegocio: nombreNegocio ?? this.nombreNegocio,
        imprimirRecibo: imprimirRecibo ?? this.imprimirRecibo,
      );
}
