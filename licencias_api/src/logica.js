// Reglas de activación. Función pura: no toca la base ni la red.

export const RESULTADOS = {
  activada: { ok: true, http: 200, mensaje: 'Licencia activada' },
  reactivada: { ok: true, http: 200, mensaje: 'Licencia reactivada en este dispositivo' },
  invalida: { ok: false, http: 403, mensaje: 'Licencia inválida' },
  revocada: { ok: false, http: 403, mensaje: 'Licencia revocada' },
  expirada: { ok: false, http: 403, mensaje: 'La licencia expiró' },
  en_uso: { ok: false, http: 409, mensaje: 'La licencia ya está en uso en otro dispositivo' },
};

const DIA_MS = 24 * 60 * 60 * 1000;

/**
 * @param {object} p
 * @param {object|null} p.licencia        fila de `licencias` o null si la clave no existe
 * @param {object|null} p.propia          activación de ESTE dispositivo (cualquier estado) o null
 * @param {number} p.activasOtros         activaciones activas de OTROS dispositivos
 * @param {Date|null} p.primeraExpiracion vencimiento ya fijado para la licencia (1.a activación)
 * @param {Date} p.ahora
 * @returns {{resultado: string, expiraEn: Date|null, accion: 'insertar'|'reactivar'|'ninguna'}}
 */
export function decidirActivacion({ licencia, propia, activasOtros, primeraExpiracion, ahora }) {
  const rechazo = (resultado, expiraEn = null) => ({ resultado, expiraEn, accion: 'ninguna' });

  if (!licencia) return rechazo('invalida');
  if (licencia.estado === 'revocada') return rechazo('revocada');

  // El vencimiento se fija en la primera activación de la licencia y no se
  // reinicia al reinstalar la app ni al activar en otro dispositivo.
  const expiraEn =
    propia?.expira_en ??
    primeraExpiracion ??
    (licencia.dias_validez ? new Date(ahora.getTime() + licencia.dias_validez * DIA_MS) : null);

  if (expiraEn && expiraEn <= ahora) return rechazo('expirada', expiraEn);

  if (propia?.estado === 'activa') {
    return { resultado: 'reactivada', expiraEn, accion: 'ninguna' };
  }
  if (activasOtros >= licencia.max_dispositivos) return rechazo('en_uso', expiraEn);

  return propia
    ? { resultado: 'reactivada', expiraEn, accion: 'reactivar' } // estaba liberada
    : { resultado: 'activada', expiraEn, accion: 'insertar' };
}
