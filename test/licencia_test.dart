import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:venta_pollos/data/repositories/config_repository.dart';
import 'package:venta_pollos/providers/licencia_provider.dart';
import 'package:venta_pollos/screens/auth/activacion_screen.dart';
import 'package:venta_pollos/services/licencia/licencia_service.dart';
import 'package:venta_pollos/services/licencia/token_licencia.dart';
import 'package:venta_pollos/utils/app_exception.dart';

import 'fixtures_licencia.dart';

/// Configuración en memoria en lugar de SQLite.
class ConfigEnMemoria extends ConfigRepository {
  final datos = <String, String>{};
  @override
  Future<String?> leer(String clave) async => datos[clave];
  @override
  Future<void> escribir(Map<String, String> valores) async =>
      datos.addAll(valores);
}

final emitido = DateTime.utc(2026, 9, 21, 14, 13, 20);

LicenciaService servicio(ConfigEnMemoria config, {http.Client? cliente}) =>
    LicenciaService(
      config,
      cliente: cliente,
      urlApi: 'https://api.prueba',
      clavePublica: clavePublicaPrueba,
      idDispositivo: () async => idDispositivoPrueba,
    );

http.Client apiQueResponde(int status, Map<String, dynamic> cuerpo,
        {void Function(Map<String, dynamic>)? alRecibir}) =>
    MockClient((req) async {
      alRecibir?.call(jsonDecode(req.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(cuerpo), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

void main() {
  group('token firmado por la API', () {
    test('la app verifica la firma del servidor', () async {
      final t =
          await TokenLicencia.verificar(tokenBetaVigente, clavePublicaPrueba);
      expect(t, isNotNull);
      expect(t!.esBeta, isTrue);
      expect(t.licenciaId, 5);
      expect(t.dispositivo, hashDispositivoPrueba);
      expect(t.expira, emitido.add(const Duration(days: 15)));
    });

    test('rechaza un token alterado', () async {
      final partes = tokenBetaVigente.split('.');
      final contenido = jsonDecode(utf8.decode(base64Url
          .decode(partes[0].padRight((partes[0].length + 3) ~/ 4 * 4, '='))));
      contenido['exp'] = null; // intento de volverla perpetua
      final falso =
          '${base64Url.encode(utf8.encode(jsonEncode(contenido))).replaceAll('=', '')}.${partes[1]}';
      expect(await TokenLicencia.verificar(falso, clavePublicaPrueba), isNull);
    });

    test('rechaza un token firmado con otra clave', () async {
      expect(
          await TokenLicencia.verificar(
              tokenBetaVigente, 'R57ATu1AFJb9+GWQ+veFJUxhQ+20/DH6jbyhLZWLbk0='),
          isNull);
      expect(
          await TokenLicencia.verificar('basura', clavePublicaPrueba), isNull);
    });

    test('acepta el número de licencia como texto (API desplegada)', () async {
      final t =
          await TokenLicencia.verificar(tokenLicComoTexto, clavePublicaPrueba);
      expect(t, isNotNull, reason: 'fallaba en el emulador con la API real');
      expect(t!.licenciaId, 7);
    });

    test('la perpetua no vence', () async {
      final t =
          await TokenLicencia.verificar(tokenPerpetuo, clavePublicaPrueba);
      expect(t!.expira, isNull);
      expect(t.vigente(DateTime.utc(2099)), isTrue);
    });
  });

  group('servicio de licencia', () {
    test('activa, guarda el token y ya no necesita internet', () async {
      final config = ConfigEnMemoria();
      late Map<String, dynamic> enviado;
      final s = servicio(config,
          cliente: apiQueResponde(200, {'ok': true, 'token': tokenBetaVigente},
              alRecibir: (b) => enviado = b));

      await s.activar('VP-7K2Q-M9XD-4TRA-HB3W');
      expect(enviado['dispositivo'], hashDispositivoPrueba);
      expect(enviado['producto'], 'venta_pollos');
      expect(config.datos['licencia_token'], tokenBetaVigente);
      expect(config.datos.values.join(), isNot(contains('VP-7K2Q')),
          reason: 'la clave no debe guardarse en el celular');

      // Nueva instancia sin red: la licencia se lee y verifica localmente.
      final sinRed = servicio(config,
          cliente:
              MockClient((_) async => throw http.ClientException('sin red')));
      expect((await sinRed.licenciaGuardada())?.licenciaId, 5);
    });

    test('muestra el mensaje del servidor al rechazar', () async {
      final s = servicio(ConfigEnMemoria(),
          cliente: apiQueResponde(409, {
            'ok': false,
            'codigo': 'en_uso',
            'mensaje': 'La licencia ya está en uso en otro dispositivo',
          }));
      expect(
          () => s.activar('VP-7K2Q-M9XD-4TRA-HB3W'),
          throwsA(isA<AppException>()
              .having((e) => e.mensaje, 'mensaje', contains('en uso'))));
    });

    test('no acepta un token emitido para otro celular', () async {
      final config = ConfigEnMemoria();
      final s = servicio(config,
          cliente:
              apiQueResponde(200, {'ok': true, 'token': tokenDeOtroCelular}));
      await expectLater(
          s.activar('VP-7K2Q-M9XD-4TRA-HB3W'), throwsA(isA<AppException>()));
      expect(config.datos['licencia_token'], isNull);

      // Ni aunque alguien copie el token en la base del celular.
      config.datos['licencia_token'] = tokenDeOtroCelular;
      expect(await s.licenciaGuardada(), isNull);
    });
  });

  group('estado de la licencia', () {
    Future<LicenciaProvider> proveedor(DateTime ahora) async {
      final config = ConfigEnMemoria()
        ..datos['licencia_token'] = tokenBetaVigente;
      final p = LicenciaProvider(servicio(config), ahora: () => ahora);
      await p.cargar();
      addTearDown(p.dispose);
      return p;
    }

    test('sin token pide activación', () async {
      final p = LicenciaProvider(servicio(ConfigEnMemoria()));
      await p.cargar();
      addTearDown(p.dispose);
      expect(p.estado, EstadoLicencia.sinLicencia);
    });

    test('beta vigente muestra los días restantes', () async {
      final p = await proveedor(emitido.add(const Duration(days: 5)));
      expect(p.estado, EstadoLicencia.activa);
      expect(p.diasRestantes, 10);
    });

    test('beta vencida bloquea el uso', () async {
      final p =
          await proveedor(emitido.add(const Duration(days: 15, minutes: 1)));
      expect(p.estado, EstadoLicencia.expirada);
    });
  });

  test('el campo da formato a la clave mientras se escribe', () {
    final f = FormatoClave();
    String escribir(String t) => f
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t))
        .text;
    expect(escribir('7k2qm9xd4trahb3w'), '7K2Q-M9XD-4TRA-HB3W');
    expect(escribir('7K2Q M9XD'), '7K2Q-M9XD');
    // Pegar la clave completa quita el prefijo VP.
    expect(escribir('VP-7K2Q-M9XD-4TRA-HB3W'), '7K2Q-M9XD-4TRA-HB3W');
    expect(escribir('7K2Q-M9XD-4TRA-HB3W-EXTRA'), '7K2Q-M9XD-4TRA-HB3W');
    // Escribir letra por letra no duplica nada (el error que vimos).
    var campo = TextEditingValue.empty;
    for (final c in 'VPZZZZZZZZZZZZZZ'.split('')) {
      campo = f.formatEditUpdate(campo, TextEditingValue(text: campo.text + c));
    }
    expect(campo.text, 'VPZZ-ZZZZ-ZZZZ-ZZZZ');
    expect(escribir(''), '');
  });
}
