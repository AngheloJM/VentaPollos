import 'package:flutter/foundation.dart';

import '../data/repositories/producto_repository.dart';
import '../models/producto.dart';

class CatalogoProvider extends ChangeNotifier {
  final ProductoRepository _repo;
  CatalogoProvider(this._repo);

  List<Categoria> categorias = [];
  List<Producto> productos = [];
  bool cargando = true;

  List<Producto> get activos => productos.where((p) => p.activo).toList();

  List<Producto> activosDe(int? categoriaId) => categoriaId == null
      ? activos
      : activos.where((p) => p.categoriaId == categoriaId).toList();

  Categoria? categoria(int id) =>
      categorias.where((c) => c.id == id).firstOrNull;

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    categorias = await _repo.categorias();
    productos = await _repo.productos();
    cargando = false;
    notifyListeners();
  }

  Future<void> guardar(Producto p) async {
    final guardado = await _repo.guardar(p);
    final i = productos.indexWhere((x) => x.id == guardado.id);
    if (i >= 0) {
      productos[i] = guardado;
    } else {
      productos.add(guardado);
    }
    notifyListeners();
  }

  Future<void> eliminar(Producto p) async {
    await _repo.eliminar(p.id!);
    productos.removeWhere((x) => x.id == p.id);
    notifyListeners();
  }

  Future<void> guardarCategoria(Categoria c) async {
    final guardada = await _repo.guardarCategoria(c);
    final i = categorias.indexWhere((x) => x.id == guardada.id);
    if (i >= 0) {
      categorias[i] = guardada;
    } else {
      categorias.add(guardada);
    }
    categorias.sort((a, b) => a.orden.compareTo(b.orden));
    notifyListeners();
  }

  Future<void> eliminarCategoria(Categoria c) async {
    await _repo.eliminarCategoria(c.id!);
    categorias.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }
}
