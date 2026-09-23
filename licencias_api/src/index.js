import { manejarActivacion } from './activar.js';
import { crearRepositorio } from './repositorio.js';
import { importarClavePrivada } from './token.js';

const json = (cuerpo, status = 200) =>
  new Response(JSON.stringify(cuerpo), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);

    if (pathname === '/v1/salud' && request.method === 'GET') {
      return json({ ok: true, servicio: 'ventapollos-licencias' });
    }

    if (pathname !== '/v1/activar') {
      return json({ ok: false, codigo: 'no_encontrado', mensaje: 'Ruta no encontrada' }, 404);
    }
    if (request.method !== 'POST') {
      return json({ ok: false, codigo: 'metodo', mensaje: 'Use POST' }, 405);
    }
    if (!env.DATABASE_URL || !env.LICENCIA_CLAVE_PRIVADA) {
      console.error('Faltan los secretos DATABASE_URL o LICENCIA_CLAVE_PRIVADA');
      return json({ ok: false, codigo: 'configuracion', mensaje: 'Servicio no disponible' }, 503);
    }

    const repo = crearRepositorio(env);
    try {
      const clavePrivada = await importarClavePrivada(env.LICENCIA_CLAVE_PRIVADA);
      return await manejarActivacion(request, { repo, clavePrivada });
    } catch (e) {
      // No se devuelven detalles internos al cliente.
      console.error('Error en activación:', e?.message);
      return json({ ok: false, codigo: 'error_interno', mensaje: 'Error interno' }, 500);
    } finally {
      ctx.waitUntil(repo.cerrar());
    }
  },
};
