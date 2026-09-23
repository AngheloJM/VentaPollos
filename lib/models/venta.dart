enum TipoPedido {
  mesa('Mesa', '🍽️'),
  llevar('Para llevar', '🛍️'),
  delivery('Delivery', '🛵');

  const TipoPedido(this.etiqueta, this.emoji);
  final String etiqueta;
  final String emoji;
}

enum MetodoPago {
  efectivo('Efectivo'),
  qr('QR'),
  tarjeta('Tarjeta');

  const MetodoPago(this.etiqueta);
  final String etiqueta;
}

class VentaItem {
  final int? productoId;
  final String nombre;

  /// Contenido del combo al momento de la venta.
  final String? descripcion;
  final int precio;
  final int cantidad;
  final String? nota;

  const VentaItem({
    this.productoId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.cantidad,
    this.nota,
  });

  int get subtotal => precio * cantidad;

  factory VentaItem.fromMap(Map<String, Object?> m) => VentaItem(
        productoId: m['producto_id'] as int?,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String?,
        precio: m['precio'] as int,
        cantidad: m['cantidad'] as int,
        nota: m['nota'] as String?,
      );

  Map<String, Object?> toMap(int ventaId) => {
        'venta_id': ventaId,
        'producto_id': productoId,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'cantidad': cantidad,
        'nota': nota,
      };
}

class Venta {
  final int? id;
  final DateTime fecha;
  final TipoPedido tipo;

  /// Número de mesa o nombre del cliente.
  final String? referencia;
  final String? nota;
  final MetodoPago metodoPago;
  final List<VentaItem> items;
  final bool anulada;

  /// Quién registró la venta (se copia el nombre por si luego cambia).
  final int? usuarioId;
  final String? usuarioNombre;

  const Venta({
    this.id,
    required this.fecha,
    required this.tipo,
    this.referencia,
    this.nota,
    required this.metodoPago,
    required this.items,
    this.anulada = false,
    this.usuarioId,
    this.usuarioNombre,
  });

  int get total => items.fold(0, (s, i) => s + i.subtotal);
  int get unidades => items.fold(0, (s, i) => s + i.cantidad);

  factory Venta.fromMap(Map<String, Object?> m, List<VentaItem> items) => Venta(
        id: m['id'] as int,
        fecha: DateTime.parse(m['fecha'] as String),
        tipo: TipoPedido.values.byName(m['tipo'] as String),
        referencia: m['referencia'] as String?,
        nota: m['nota'] as String?,
        metodoPago: MetodoPago.values.byName(m['metodo_pago'] as String),
        anulada: (m['anulada'] as int) == 1,
        usuarioId: m['usuario_id'] as int?,
        usuarioNombre: m['usuario_nombre'] as String?,
        items: items,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'fecha': fecha.toIso8601String(),
        'tipo': tipo.name,
        'referencia': referencia,
        'nota': nota,
        'metodo_pago': metodoPago.name,
        'total': total,
        'anulada': anulada ? 1 : 0,
        'usuario_id': usuarioId,
        'usuario_nombre': usuarioNombre,
      };

  Venta conId(int nuevoId) => Venta(
        id: nuevoId,
        fecha: fecha,
        tipo: tipo,
        referencia: referencia,
        nota: nota,
        metodoPago: metodoPago,
        items: items,
        anulada: anulada,
        usuarioId: usuarioId,
        usuarioNombre: usuarioNombre,
      );
}
