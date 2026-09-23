// Lista o libera los dispositivos de una licencia (celular nuevo, robado o formateado).
//
//   npm run liberar -- --licencia 3              # lista sus dispositivos
//   npm run liberar -- --licencia 3 --activacion 7   # libera uno
//   npm run liberar -- --licencia 3 --revocar    # revoca la licencia completa
import { parseArgs } from 'node:util';
import { conectar } from './_db.mjs';

const { values: a } = parseArgs({
  options: {
    licencia: { type: 'string' },
    activacion: { type: 'string' },
    revocar: { type: 'boolean', default: false },
  },
});
const licenciaId = Number.parseInt(a.licencia ?? '', 10);
if (!(licenciaId > 0)) {
  console.error('Indique --licencia <id>');
  process.exit(1);
}

const pool = conectar();
try {
  if (a.revocar) {
    const r = await pool.query(`UPDATE licencias SET estado = 'revocada' WHERE id = $1`, [licenciaId]);
    console.log(r.rowCount ? `Licencia #${licenciaId} revocada.` : 'Licencia no encontrada.');
  } else if (a.activacion) {
    const r = await pool.query(
      `UPDATE activaciones SET estado = 'liberada', liberada_en = now()
       WHERE id = $1 AND licencia_id = $2 AND estado = 'activa'`,
      [Number.parseInt(a.activacion, 10), licenciaId],
    );
    console.log(r.rowCount ? 'Dispositivo liberado.' : 'No hay una activación activa con ese id.');
  }

  const { rows } = await pool.query(
    `SELECT a.id, a.estado, a.modelo, a.version_app,
            to_char(a.activada_en, 'YYYY-MM-DD HH24:MI') AS activada,
            to_char(a.expira_en, 'YYYY-MM-DD') AS expira
     FROM activaciones a WHERE a.licencia_id = $1 ORDER BY a.activada_en`,
    [licenciaId],
  );
  console.table(rows);
} finally {
  await pool.end();
}
