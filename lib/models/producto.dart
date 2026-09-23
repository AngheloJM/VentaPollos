class Categoria {
  final int id;
  final String nombre;
  final String emoji;

  const Categoria({required this.id, required this.nombre, required this.emoji});

  factory Categoria.fromMap(Map<String, Object?> m) => Categoria(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        emoji: m['emoji'] as String,
      );
}

class Producto {
  final int? id;
  final int categoriaId;
  final String nombre;

  /// Precio en centavos.
  final int precio;
  final String emoji;
  final bool activo;

  const Producto({
    this.id,
    required this.categoriaId,
    required this.nombre,
    required this.precio,
    this.emoji = '🍗',
    this.activo = true,
  });

  factory Producto.fromMap(Map<String, Object?> m) => Producto(
        id: m['id'] as int,
        categoriaId: m['categoria_id'] as int,
        nombre: m['nombre'] as String,
        precio: m['precio'] as int,
        emoji: m['emoji'] as String,
        activo: (m['activo'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'categoria_id': categoriaId,
        'nombre': nombre,
        'precio': precio,
        'emoji': emoji,
        'activo': activo ? 1 : 0,
      };

  Producto copyWith({
    int? categoriaId,
    String? nombre,
    int? precio,
    String? emoji,
    bool? activo,
  }) =>
      Producto(
        id: id,
        categoriaId: categoriaId ?? this.categoriaId,
        nombre: nombre ?? this.nombre,
        precio: precio ?? this.precio,
        emoji: emoji ?? this.emoji,
        activo: activo ?? this.activo,
      );
}
