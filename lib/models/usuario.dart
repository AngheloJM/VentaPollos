enum Rol {
  admin('Administrador'),
  cajero('Cajero');

  const Rol(this.etiqueta);
  final String etiqueta;
}

/// Datos públicos del usuario. El hash del PIN nunca sale del repositorio.
class Usuario {
  final int id;
  final String nombre;
  final Rol rol;
  final bool activo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    this.activo = true,
  });

  bool get esAdmin => rol == Rol.admin;
  String get inicial => nombre.isEmpty ? '?' : nombre[0].toUpperCase();

  factory Usuario.fromMap(Map<String, Object?> m) => Usuario(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        rol: Rol.values.byName(m['rol'] as String),
        activo: (m['activo'] as int) == 1,
      );

  Usuario copyWith({String? nombre, Rol? rol, bool? activo}) => Usuario(
        id: id,
        nombre: nombre ?? this.nombre,
        rol: rol ?? this.rol,
        activo: activo ?? this.activo,
      );
}
