class Categoria {
  final int? id;
  final String nombre;
  final String emoji;
  final int orden;

  const Categoria({
    this.id,
    required this.nombre,
    this.emoji = '🍗',
    this.orden = 0,
  });

  factory Categoria.fromMap(Map<String, Object?> m) => Categoria(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        emoji: m['emoji'] as String,
        orden: m['orden'] as int,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'orden': orden,
      };

  Categoria copyWith({String? nombre, String? emoji, int? orden}) => Categoria(
        id: id,
        nombre: nombre ?? this.nombre,
        emoji: emoji ?? this.emoji,
        orden: orden ?? this.orden,
      );
}

class Producto {
  final int? id;
  final int categoriaId;
  final String nombre;

  /// Contenido del combo o detalle del plato; se imprime en la comanda.
  final String? descripcion;

  /// Precio en centavos.
  final int precio;
  final String emoji;
  final bool activo;

  const Producto({
    this.id,
    required this.categoriaId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.emoji = '🍗',
    this.activo = true,
  });

  factory Producto.fromMap(Map<String, Object?> m) => Producto(
        id: m['id'] as int,
        categoriaId: m['categoria_id'] as int,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String?,
        precio: m['precio'] as int,
        emoji: m['emoji'] as String,
        activo: (m['activo'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'categoria_id': categoriaId,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'emoji': emoji,
        'activo': activo ? 1 : 0,
      };

  Producto copyWith({
    int? categoriaId,
    String? nombre,
    String? descripcion,
    int? precio,
    String? emoji,
    bool? activo,
  }) =>
      Producto(
        id: id,
        categoriaId: categoriaId ?? this.categoriaId,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        precio: precio ?? this.precio,
        emoji: emoji ?? this.emoji,
        activo: activo ?? this.activo,
      );
}
