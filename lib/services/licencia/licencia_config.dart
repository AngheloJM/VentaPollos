/// Configuración del servicio de licencias. La clave
/// pública solo sirve para VERIFICAR firmas, no para crearlas.
class LicenciaConfig {
  static const producto = 'venta_pollos';
  static const versionApp = '1.0.0';

  /// Se define al compilar para no publicar la dirección en el repositorio:
  ///   flutter run --dart-define-from-file=config/licencia.json
  static const urlApi = String.fromEnvironment('LICENCIA_API');

  /// Clave pública Ed25519 (32 bytes en base64) del servidor de licencias.
  static const clavePublica = String.fromEnvironment(
    'LICENCIA_CLAVE_PUBLICA',
    defaultValue: 'R57ATu1AFJb9+GWQ+veFJUxhQ+20/DH6jbyhLZWLbk0=',
  );
}
