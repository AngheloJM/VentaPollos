// Formato de clave: VP-XXXX-XXXX-XXXX-XXXX con alfabeto Crockford base32
// (sin I, L, O ni U para evitar confusiones al dictarla). 80 bits aleatorios.
export const ALFABETO = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const FORMATO_CLAVE = /^VP(-[0-9A-HJKMNP-TV-Z]{4}){4}$/;
const HEX64 = /^[0-9a-f]{64}$/;

/** Normaliza lo que escribe el usuario: mayúsculas, sin espacios, O->0, I/L->1. */
export function normalizarClave(texto) {
  if (typeof texto !== 'string') return null;
  const limpia = texto
    .toUpperCase()
    .replace(/\s+/g, '')
    .replace(/O/g, '0')
    .replace(/[IL]/g, '1');
  return FORMATO_CLAVE.test(limpia) ? limpia : null;
}

export const esHex64 = (v) => typeof v === 'string' && HEX64.test(v);

/** Texto corto y seguro para guardar (modelo, versión). */
export function textoCorto(v, max = 60) {
  if (typeof v !== 'string') return null;
  const t = v.replace(/[\u0000-\u001f]/g, '').trim();
  return t ? t.slice(0, max) : null;
}

export async function sha256Hex(texto) {
  const datos = new TextEncoder().encode(texto);
  const hash = await crypto.subtle.digest('SHA-256', datos);
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
