import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { describe, it } from 'node:test';

import { manejarActivacion, MAX_FALLOS_POR_IP } from '../src/activar.js';
import { decidirActivacion } from '../src/logica.js';
import { importarClavePrivada, importarClavePublica, verificarToken } from '../src/token.js';
import { normalizarClave, sha256Hex } from '../src/validacion.js';

const DIA = 24 * 60 * 60 * 1000;
const T0 = new Date('2026-09-23T12:00:00Z');
const CEL_A = 'a'.repeat(64);
const CEL_B = 'b'.repeat(64);
const CLAVE_BETA = 'VP-7K2Q-M9XD-4TRA-HB3W';
const CLAVE_FULL = 'VP-0000-1111-2222-3333';

async function clavesDePrueba() {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const privada = privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64');
  const publica = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');
  return { privada: await importarClavePrivada(privada), publica: await importarClavePublica(publica) };
}

/** Simula Neon con la misma interfaz que src/repositorio.js. */
async function repoFalso() {
  const licencias = [
    { id: 1, producto: 'venta_pollos', clave_hash: await sha256Hex(CLAVE_BETA), tipo: 'beta', max_dispositivos: 1, dias_validez: 15, estado: 'activa' },
    { id: 2, producto: 'venta_pollos', clave_hash: await sha256Hex(CLAVE_FULL), tipo: 'completa', max_dispositivos: 1, dias_validez: null, estado: 'activa' },
  ];
  const activaciones = [];
  const intentos = [];
  return {
    licencias,
    activaciones,
    intentos,
    async fallosRecientes(ip) {
      return intentos.filter((i) => i.ip === ip && !['activada', 'reactivada'].includes(i.resultado)).length;
    },
    async registrarIntento(i) {
      intentos.push(i);
    },
    async activar({ claveHash, producto, dispositivo, decidir }) {
      const licencia = licencias.find((l) => l.clave_hash === claveHash && l.producto === producto) ?? null;
      if (!licencia) return { licencia: null, decision: decidir({ licencia: null }) };
      const acts = activaciones.filter((a) => a.licencia_id === licencia.id);
      const propia = acts.find((a) => a.dispositivo_hash === dispositivo) ?? null;
      const activasOtros = acts.filter((a) => a.estado === 'activa' && a.dispositivo_hash !== dispositivo).length;
      const primeraExpiracion = acts.find((a) => a.expira_en)?.expira_en ?? null;
      const decision = decidir({ licencia, propia, activasOtros, primeraExpiracion });
      if (decision.accion === 'insertar') {
        activaciones.push({ licencia_id: licencia.id, dispositivo_hash: dispositivo, estado: 'activa', expira_en: decision.expiraEn });
      } else if (decision.accion === 'reactivar') {
        propia.estado = 'activa';
      }
      return { licencia, decision };
    },
  };
}

const peticion = (cuerpo, ip = '203.0.113.5') =>
  new Request('https://api.test/v1/activar', {
    method: 'POST',
    headers: { 'cf-connecting-ip': ip, 'content-type': 'application/json' },
    body: typeof cuerpo === 'string' ? cuerpo : JSON.stringify(cuerpo),
  });

async function activar(repo, claves, cuerpo, ahora = T0, ip) {
  const r = await manejarActivacion(peticion(cuerpo, ip), { repo, clavePrivada: claves.privada, ahora: () => ahora });
  return { status: r.status, cuerpo: await r.json() };
}

describe('validación de clave', () => {
  it('normaliza minúsculas, espacios y letras confusas', () => {
    assert.equal(normalizarClave(' vp-7k2q-m9xd-4tra-hb3w '), CLAVE_BETA);
    assert.equal(normalizarClave('VP-OOOO-IIII-2222-3333'), 'VP-0000-1111-2222-3333');
  });
  it('rechaza formatos inválidos', () => {
    assert.equal(normalizarClave('VP-123'), null);
    assert.equal(normalizarClave("VP-AAAA-AAAA-AAAA-AAAA'; DROP TABLE licencias;--"), null);
    assert.equal(normalizarClave(42), null);
  });
});

describe('reglas de activación', () => {
  const beta = { id: 1, tipo: 'beta', max_dispositivos: 1, dias_validez: 15, estado: 'activa' };
  it('la beta vence desde la primera activación', () => {
    const d = decidirActivacion({ licencia: beta, propia: null, activasOtros: 0, primeraExpiracion: null, ahora: T0 });
    assert.equal(d.resultado, 'activada');
    assert.equal(d.expiraEn.getTime(), T0.getTime() + 15 * DIA);
  });
  it('una licencia completa no vence', () => {
    const d = decidirActivacion({
      licencia: { ...beta, tipo: 'completa', dias_validez: null },
      propia: null, activasOtros: 0, primeraExpiracion: null, ahora: T0,
    });
    assert.equal(d.expiraEn, null);
  });
});

describe('POST /v1/activar', async () => {
  const claves = await clavesDePrueba();

  it('activa una beta y devuelve un token firmado verificable', async () => {
    const repo = await repoFalso();
    const r = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A, modelo: 'Pixel 7' });
    assert.equal(r.status, 200);
    assert.equal(r.cuerpo.codigo, 'activada');
    const contenido = await verificarToken(r.cuerpo.token, claves.publica);
    assert.equal(contenido.tipo, 'beta');
    assert.equal(contenido.disp, CEL_A);
    assert.equal(contenido.clave, await sha256Hex(CLAVE_BETA));
    assert.equal(contenido.exp, Math.floor((T0.getTime() + 15 * DIA) / 1000));
    assert.equal(r.cuerpo.token.includes(CLAVE_BETA), false, 'el token no debe contener la clave');
  });

  it('un token alterado no pasa la verificación', async () => {
    const repo = await repoFalso();
    const { cuerpo } = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A });
    const [datos, firma] = cuerpo.token.split('.');
    const falso = Buffer.from(JSON.stringify({ ...JSON.parse(Buffer.from(datos, 'base64url')), exp: null }))
      .toString('base64url');
    assert.equal(await verificarToken(`${falso}.${firma}`, claves.publica), null);
  });

  it('el mismo celular puede reactivar (reinstalación) con el mismo vencimiento', async () => {
    const repo = await repoFalso();
    const primera = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A });
    const segunda = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A }, new Date(T0.getTime() + 3 * DIA));
    assert.equal(segunda.cuerpo.codigo, 'reactivada');
    assert.equal(segunda.cuerpo.licencia.expira_en, primera.cuerpo.licencia.expira_en);
  });

  it('otro celular recibe "en uso"', async () => {
    const repo = await repoFalso();
    await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A });
    const r = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_B });
    assert.equal(r.status, 409);
    assert.equal(r.cuerpo.codigo, 'en_uso');
  });

  it('la beta vencida se rechaza aunque reinstalen en el mismo celular', async () => {
    const repo = await repoFalso();
    await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A });
    const r = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A }, new Date(T0.getTime() + 16 * DIA));
    assert.equal(r.status, 403);
    assert.equal(r.cuerpo.codigo, 'expirada');
  });

  it('liberar el celular permite activar otro, sin reiniciar el vencimiento de la beta', async () => {
    const repo = await repoFalso();
    const primera = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A });
    repo.activaciones[0].estado = 'liberada';
    const otro = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_B }, new Date(T0.getTime() + 5 * DIA));
    assert.equal(otro.cuerpo.codigo, 'activada');
    assert.equal(otro.cuerpo.licencia.expira_en, primera.cuerpo.licencia.expira_en);
  });

  it('la licencia completa es perpetua', async () => {
    const repo = await repoFalso();
    const r = await activar(repo, claves, { clave: CLAVE_FULL, dispositivo: CEL_A });
    assert.equal(r.cuerpo.licencia.expira_en, null);
    assert.equal((await verificarToken(r.cuerpo.token, claves.publica)).exp, null);
  });

  it('rechaza revocadas, inexistentes y datos inválidos', async () => {
    const repo = await repoFalso();
    repo.licencias[1].estado = 'revocada';
    assert.equal((await activar(repo, claves, { clave: CLAVE_FULL, dispositivo: CEL_A })).cuerpo.codigo, 'revocada');
    assert.equal((await activar(repo, claves, { clave: 'VP-ZZZZ-ZZZZ-ZZZZ-ZZZZ', dispositivo: CEL_A })).cuerpo.codigo, 'invalida');
    assert.equal((await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: 'celular' })).status, 400);
    assert.equal((await activar(repo, claves, '{no es json')).status, 400);
  });

  it(`bloquea una IP tras ${MAX_FALLOS_POR_IP} intentos fallidos`, async () => {
    const repo = await repoFalso();
    for (let i = 0; i < MAX_FALLOS_POR_IP; i++) {
      await activar(repo, claves, { clave: 'VP-ZZZZ-ZZZZ-ZZZZ-ZZZZ', dispositivo: CEL_B }, T0, '198.51.100.9');
    }
    const r = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A }, T0, '198.51.100.9');
    assert.equal(r.status, 429);
    const otraIp = await activar(repo, claves, { clave: CLAVE_BETA, dispositivo: CEL_A }, T0, '198.51.100.10');
    assert.equal(otraIp.status, 200);
  });
});
