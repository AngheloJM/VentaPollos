import 'package:flutter/foundation.dart';

import '../models/producto.dart';
import '../models/venta.dart';

class LineaCarrito {
  final Producto producto;
  int cantidad;
  String? nota;
  LineaCarrito(this.producto, {this.cantidad = 1});

  int get subtotal => producto.precio * cantidad;
}

class CarritoProvider extends ChangeNotifier {
  final List<LineaCarrito> _lineas = [];
  List<LineaCarrito> get lineas => List.unmodifiable(_lineas);

  TipoPedido tipo = TipoPedido.llevar;
  MetodoPago metodoPago = MetodoPago.efectivo;
  String referencia = '';
  String nota = '';

  bool get vacio => _lineas.isEmpty;
  int get total => _lineas.fold(0, (s, l) => s + l.subtotal);
  int get unidades => _lineas.fold(0, (s, l) => s + l.cantidad);

  int cantidadDe(Producto p) =>
      _lineas.where((l) => l.producto.id == p.id).firstOrNull?.cantidad ?? 0;

  void agregar(Producto p) {
    final linea = _lineas.where((l) => l.producto.id == p.id).firstOrNull;
    if (linea != null) {
      linea.cantidad++;
    } else {
      _lineas.add(LineaCarrito(p));
    }
    notifyListeners();
  }

  void cambiarCantidad(LineaCarrito linea, int delta) {
    linea.cantidad += delta;
    if (linea.cantidad <= 0) _lineas.remove(linea);
    notifyListeners();
  }

  void quitar(LineaCarrito linea) {
    _lineas.remove(linea);
    notifyListeners();
  }

  void ponerNota(LineaCarrito linea, String? texto) {
    linea.nota = (texto?.trim().isEmpty ?? true) ? null : texto!.trim();
    notifyListeners();
  }

  void setTipo(TipoPedido t) {
    tipo = t;
    notifyListeners();
  }

  void setMetodoPago(MetodoPago m) {
    metodoPago = m;
    notifyListeners();
  }

  Venta aVenta() => Venta(
        fecha: DateTime.now(),
        tipo: tipo,
        referencia: referencia.trim().isEmpty ? null : referencia.trim(),
        nota: nota.trim().isEmpty ? null : nota.trim(),
        metodoPago: metodoPago,
        items: [
          for (final l in _lineas)
            VentaItem(
              productoId: l.producto.id,
              nombre: l.producto.nombre,
              precio: l.producto.precio,
              cantidad: l.cantidad,
              nota: l.nota,
            ),
        ],
      );

  void limpiar() {
    _lineas.clear();
    referencia = '';
    nota = '';
    tipo = TipoPedido.llevar;
    metodoPago = MetodoPago.efectivo;
    notifyListeners();
  }
}
