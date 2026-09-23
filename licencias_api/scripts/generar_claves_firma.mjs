// Genera el par de claves Ed25519 para firmar los tokens de licencia.
//
//   npm run claves-firma
//
// - La clave PRIVADA se guarda en ~/.config/ventapollos/ con permisos 600.
//   Súbala como secreto LICENCIA_CLAVE_PRIVADA en Cloudflare y NUNCA la
//   agregue al repositorio.
// - La clave PÚBLICA se imprime: va dentro de la app (no es secreta).
import { generateKeyPairSync } from 'node:crypto';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const carpeta = join(homedir(), '.config', 'ventapollos');
const rutaPrivada = join(carpeta, 'licencia_clave_privada.b64');
const rutaPublica = join(carpeta, 'licencia_clave_publica.b64');

if (existsSync(rutaPrivada) && !process.argv.includes('--forzar')) {
  console.error(`Ya existe ${rutaPrivada}.`);
  console.error('Regenerarla invalida todos los tokens emitidos. Use --forzar si está seguro.');
  process.exit(1);
}

const { publicKey, privateKey } = generateKeyPairSync('ed25519');
const privada = privateKey.export({ format: 'der', type: 'pkcs8' }).toString('base64');
// Formato "raw" (32 bytes): son los últimos 32 bytes del SPKI DER de Ed25519.
const publica = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64');

mkdirSync(carpeta, { recursive: true, mode: 0o700 });
writeFileSync(rutaPrivada, privada, { mode: 0o600 });
writeFileSync(rutaPublica, publica, { mode: 0o644 });

console.log('Clave privada guardada en:', rutaPrivada, '(permisos 600, no la comparta)');
console.log('Clave pública (va en la app):');
console.log(publica);
