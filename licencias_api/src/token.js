// Token de licencia: base64url(JSON del contenido) + "." + base64url(firma Ed25519).
// La app lo verifica sin internet con la clave pública.

const b64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

const deB64url = (texto) => {
  const b64 = texto.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};

const deB64 = (texto) => Uint8Array.from(atob(texto.trim()), (c) => c.charCodeAt(0));

let cache = { origen: null, clave: null };

/** Importa la clave privada (PKCS#8 en base64). Se cachea por instancia del Worker. */
export async function importarClavePrivada(pkcs8Base64) {
  if (cache.origen === pkcs8Base64) return cache.clave;
  const clave = await crypto.subtle.importKey('pkcs8', deB64(pkcs8Base64), { name: 'Ed25519' }, false, [
    'sign',
  ]);
  cache = { origen: pkcs8Base64, clave };
  return clave;
}

export async function importarClavePublica(rawBase64) {
  return crypto.subtle.importKey('raw', deB64(rawBase64), { name: 'Ed25519' }, false, ['verify']);
}

export async function firmarToken(contenido, clavePrivada) {
  const cuerpo = b64url(new TextEncoder().encode(JSON.stringify(contenido)));
  const firma = await crypto.subtle.sign({ name: 'Ed25519' }, clavePrivada, new TextEncoder().encode(cuerpo));
  return `${cuerpo}.${b64url(firma)}`;
}

/** Devuelve el contenido si la firma es válida, o null. (La app hace lo mismo en Dart.) */
export async function verificarToken(token, clavePublica) {
  const partes = typeof token === 'string' ? token.split('.') : [];
  if (partes.length !== 2) return null;
  const [cuerpo, firma] = partes;
  const ok = await crypto.subtle.verify(
    { name: 'Ed25519' },
    clavePublica,
    deB64url(firma),
    new TextEncoder().encode(cuerpo),
  );
  return ok ? JSON.parse(new TextDecoder().decode(deB64url(cuerpo))) : null;
}
