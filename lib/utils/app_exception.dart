/// Error de regla de negocio con mensaje apto para mostrar al usuario.
class AppException implements Exception {
  final String mensaje;
  AppException(this.mensaje);

  @override
  String toString() => mensaje;
}
