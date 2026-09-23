-- Esquema de licencias (PostgreSQL / Neon).
-- Solo agrega objetos nuevos; es seguro ejecutarlo más de una vez.
-- La app nunca se conecta a esta base: lo hace únicamente la API de licencias.

BEGIN;

-- Una fila por clave emitida. La clave nunca se guarda en texto plano.
CREATE TABLE IF NOT EXISTS licencias (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave_hash       TEXT        NOT NULL UNIQUE CHECK (clave_hash ~ '^[0-9a-f]{64}$'), -- SHA-256 en hex
  producto         TEXT        NOT NULL DEFAULT 'venta_pollos',
  tipo             TEXT        NOT NULL CHECK (tipo IN ('beta', 'completa')),
  cliente          TEXT,
  max_dispositivos INT         NOT NULL DEFAULT 1 CHECK (max_dispositivos > 0),
  dias_validez     INT         CHECK (dias_validez IS NULL OR dias_validez > 0),        -- NULL = perpetua
  estado           TEXT        NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa', 'revocada')),
  creada_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
  notas            TEXT,
  CONSTRAINT beta_con_vencimiento CHECK (tipo <> 'beta' OR dias_validez IS NOT NULL)
);

-- Un registro por dispositivo que activó una licencia.
-- expira_en se fija en la primera activación y no cambia al reinstalar la app.
CREATE TABLE IF NOT EXISTS activaciones (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  licencia_id      BIGINT      NOT NULL REFERENCES licencias (id) ON DELETE RESTRICT,
  dispositivo_hash TEXT        NOT NULL CHECK (dispositivo_hash ~ '^[0-9a-f]{64}$'),  -- SHA-256 del ANDROID_ID
  modelo           TEXT,
  version_app      TEXT,
  activada_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expira_en        TIMESTAMPTZ,                                                     -- NULL = perpetua
  estado           TEXT        NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa', 'liberada')),
  liberada_en      TIMESTAMPTZ,
  UNIQUE (licencia_id, dispositivo_hash)
);

CREATE INDEX IF NOT EXISTS activaciones_activas_por_licencia
  ON activaciones (licencia_id) WHERE estado = 'activa';

-- Auditoría y límite de intentos por IP (evita probar claves al azar).
CREATE TABLE IF NOT EXISTS intentos_activacion (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  licencia_id      BIGINT      REFERENCES licencias (id) ON DELETE SET NULL,
  dispositivo_hash TEXT,
  ip               INET,
  resultado        TEXT        NOT NULL,  -- activada, reactivada, expirada, en_uso, invalida, revocada
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS intentos_por_ip_y_fecha
  ON intentos_activacion (ip, creado_en);

COMMENT ON TABLE licencias IS 'Claves de licencia emitidas (solo hash SHA-256).';
COMMENT ON TABLE activaciones IS 'Dispositivos registrados por licencia; la beta vence desde la 1.a activación.';
COMMENT ON TABLE intentos_activacion IS 'Registro de cada intento de activación.';

COMMIT;
