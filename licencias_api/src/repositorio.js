import { Pool } from '@neondatabase/serverless';

const VENTANA_INTENTOS_MIN = 15;

/**
 * Acceso a Neon. Cada petición abre su propio pool (requisito de Workers);
 * quien lo usa debe llamar a `cerrar()` al terminar.
 */
export function crearRepositorio(env) {
  const pool = new Pool({ connectionString: env.DATABASE_URL });

  return {
    async cerrar() {
      await pool.end();
    },

    async fallosRecientes(ip) {
      if (!ip) return 0;
      const { rows } = await pool.query(
        `SELECT count(*)::int AS n FROM intentos_activacion
         WHERE ip = $1 AND resultado NOT IN ('activada', 'reactivada')
           AND creado_en > now() - make_interval(mins => $2)`,
        [ip, VENTANA_INTENTOS_MIN],
      );
      return rows[0].n;
    },

    async registrarIntento({ licenciaId, dispositivo, ip, resultado }) {
      await pool.query(
        `INSERT INTO intentos_activacion (licencia_id, dispositivo_hash, ip, resultado)
         VALUES ($1, $2, $3, $4)`,
        [licenciaId ?? null, dispositivo ?? null, ip ?? null, resultado],
      );
    },

    /**
     * Ejecuta `decidir` dentro de una transacción con la licencia bloqueada
     * (FOR UPDATE), para que dos activaciones simultáneas no superen el máximo.
     */
    async activar({ claveHash, producto, dispositivo, modelo, versionApp, decidir }) {
      const cliente = await pool.connect();
      try {
        await cliente.query('BEGIN');
        const lic = await cliente.query(
          `SELECT id, producto, tipo, max_dispositivos, dias_validez, estado
           FROM licencias WHERE clave_hash = $1 AND producto = $2 FOR UPDATE`,
          [claveHash, producto],
        );
        const licencia = lic.rows[0] ?? null;
        if (!licencia) {
          await cliente.query('ROLLBACK');
          return { licencia: null, decision: decidir({ licencia: null }) };
        }

        const acts = await cliente.query(
          `SELECT id, dispositivo_hash, estado, expira_en FROM activaciones
           WHERE licencia_id = $1 ORDER BY activada_en`,
          [licencia.id],
        );
        const propia = acts.rows.find((a) => a.dispositivo_hash === dispositivo) ?? null;
        const activasOtros = acts.rows.filter(
          (a) => a.estado === 'activa' && a.dispositivo_hash !== dispositivo,
        ).length;
        const primeraExpiracion = acts.rows.find((a) => a.expira_en)?.expira_en ?? null;

        const decision = decidir({ licencia, propia, activasOtros, primeraExpiracion });

        if (decision.accion === 'insertar') {
          await cliente.query(
            `INSERT INTO activaciones (licencia_id, dispositivo_hash, modelo, version_app, expira_en)
             VALUES ($1, $2, $3, $4, $5)`,
            [licencia.id, dispositivo, modelo, versionApp, decision.expiraEn],
          );
        } else if (decision.accion === 'reactivar') {
          await cliente.query(
            `UPDATE activaciones
             SET estado = 'activa', liberada_en = NULL, modelo = $3, version_app = $4
             WHERE licencia_id = $1 AND dispositivo_hash = $2`,
            [licencia.id, dispositivo, modelo, versionApp],
          );
        } else if (decision.resultado === 'reactivada') {
          await cliente.query(
            `UPDATE activaciones SET modelo = $3, version_app = $4
             WHERE licencia_id = $1 AND dispositivo_hash = $2`,
            [licencia.id, dispositivo, modelo, versionApp],
          );
        }
        await cliente.query('COMMIT');
        return { licencia, decision };
      } catch (e) {
        await cliente.query('ROLLBACK').catch(() => {});
        throw e;
      } finally {
        cliente.release();
      }
    },
  };
}
