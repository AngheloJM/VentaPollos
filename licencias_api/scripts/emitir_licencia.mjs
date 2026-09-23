// Emite una licencia nueva y muestra la clave UNA sola vez.
//
//   npm run emitir -- --tipo beta --dias 15 --cliente "Pollería X"
//   npm run emitir -- --tipo completa --cliente "Pollería X" --max 2
//
// En la base solo se guarda el SHA-256 de la clave.
import { randomBytes } from 'node:crypto';
import { parseArgs } from 'node:util';
import { ALFABETO, sha256Hex } from '../src/validacion.js';
import { conectar } from './_db.mjs';

const { values: a } = parseArgs({
  options: {
    tipo: { type: 'string' },
    dias: { type: 'string' },
    cliente: { type: 'string' },
    max: { type: 'string', default: '1' },
    notas: { type: 'string' },
  },
});

if (!['beta', 'completa'].includes(a.tipo)) {
  console.error('Indique --tipo beta o --tipo completa');
  process.exit(1);
}
const dias = a.dias ? Number.parseInt(a.dias, 10) : null;
if (a.tipo === 'beta' && !(dias > 0)) {
  console.error('Una licencia beta requiere --dias (por ejemplo --dias 15)');
  process.exit(1);
}
const max = Number.parseInt(a.max, 10);
if (!(max > 0)) {
  console.error('--max debe ser un número mayor que 0');
  process.exit(1);
}

/** 80 bits aleatorios en Crockford base32: VP-XXXX-XXXX-XXXX-XXXX */
function generarClave() {
  const bytes = randomBytes(10);
  let bits = 0n;
  for (const b of bytes) bits = (bits << 8n) | BigInt(b);
  let texto = '';
  for (let i = 0; i < 16; i++) {
    texto = ALFABETO[Number(bits & 31n)] + texto;
    bits >>= 5n;
  }
  return 'VP-' + texto.match(/.{4}/g).join('-');
}

const clave = generarClave();
const pool = conectar();
try {
  const { rows } = await pool.query(
    `INSERT INTO licencias (clave_hash, tipo, cliente, max_dispositivos, dias_validez, notas)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [await sha256Hex(clave), a.tipo, a.cliente ?? null, max, dias, a.notas ?? null],
  );
  console.log(`Licencia #${rows[0].id} (${a.tipo}${dias ? `, ${dias} días` : ', perpetua'}, ${max} dispositivo(s))`);
  console.log('Clave (se muestra solo esta vez, entréguela al cliente):');
  console.log(clave);
} finally {
  await pool.end();
}
