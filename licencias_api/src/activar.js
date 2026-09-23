import { decidirActivacion, RESULTADOS } from './logica.js';
import { firmarToken } from './token.js';
import { esHex64, normalizarClave, sha256Hex, textoCorto } from './validacion.js';

export const MAX_FALLOS_POR_IP = 10;
const PRODUCTOS = new Set(['venta_pollos']);

const json = (cuerpo, status = 200) =>
  new Response(JSON.stringify(cuerpo), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

const error = (codigo, mensaje, status) => json({ ok: false, codigo, mensaje }, status);

/**
 * POST /v1/activar
 * Cuerpo: { clave, dispositivo (SHA-256 hex del ANDROID_ID), producto?, modelo?, version_app? }
 *
 * @param {Request} request
 * @param {{repo: object, clavePrivada: CryptoKey, ahora?: () => Date}} deps
 */
export async function manejarActivacion(request, { repo, clavePrivada, ahora = () => new Date() }) {
  const ip = request.headers.get('cf-connecting-ip');

  let datos;
  try {
    const texto = await request.text();
    if (texto.length > 2048) return error('solicitud_invalida', 'Solicitud demasiado grande', 413);
    datos = JSON.parse(texto);
  } catch {
    return error('solicitud_invalida', 'JSON inválido', 400);
  }

  const clave = normalizarClave(datos?.clave);
  const dispositivo = esHex64(datos?.dispositivo) ? datos.dispositivo : null;
  const producto = datos?.producto ?? 'venta_pollos';
  if (!dispositivo || !PRODUCTOS.has(producto)) {
    return error('solicitud_invalida', 'Datos de activación incompletos', 400);
  }

  if ((await repo.fallosRecientes(ip)) >= MAX_FALLOS_POR_IP) {
    return error('demasiados_intentos', 'Demasiados intentos. Intente más tarde.', 429);
  }

  if (!clave) {
    await repo.registrarIntento({ dispositivo, ip, resultado: 'invalida' });
    const r = RESULTADOS.invalida;
    return error('invalida', r.mensaje, r.http);
  }

  const claveHash = await sha256Hex(clave);
  const momento = ahora();
  const { licencia, decision } = await repo.activar({
    claveHash,
    producto,
    dispositivo,
    modelo: textoCorto(datos.modelo),
    versionApp: textoCorto(datos.version_app, 20),
    decidir: (p) => decidirActivacion({ ...p, ahora: momento }),
  });

  await repo.registrarIntento({
    licenciaId: licencia?.id,
    dispositivo,
    ip,
    resultado: decision.resultado,
  });

  const r = RESULTADOS[decision.resultado];
  if (!r.ok) {
    return json(
      {
        ok: false,
        codigo: decision.resultado,
        mensaje: r.mensaje,
        ...(decision.resultado === 'expirada' && { expira_en: decision.expiraEn?.toISOString() }),
      },
      r.http,
    );
  }

  const exp = decision.expiraEn ? Math.floor(decision.expiraEn.getTime() / 1000) : null;
  const token = await firmarToken(
    {
      v: 1,
      prod: producto,
      lic: licencia.id,
      tipo: licencia.tipo,
      disp: dispositivo,
      clave: claveHash,
      iat: Math.floor(momento.getTime() / 1000),
      exp,
    },
    clavePrivada,
  );

  return json({
    ok: true,
    codigo: decision.resultado,
    mensaje: r.mensaje,
    token,
    licencia: {
      tipo: licencia.tipo,
      expira_en: decision.expiraEn ? decision.expiraEn.toISOString() : null,
    },
  });
}
