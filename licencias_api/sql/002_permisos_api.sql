-- Permisos mínimos para el usuario que usa la API (Cloudflare Worker).
--
-- 1. En la consola de Neon: Roles -> New role -> nombre "licencias_api".
--    Neon genera la contraseña; cópiela directamente al secreto DATABASE_URL
--    de Cloudflare (no la guarde en archivos ni la comparta por chat).
-- 2. Ejecute este archivo con el usuario dueño (neondb_owner).
--
-- La API no puede borrar nada ni crear licencias: eso se hace solo desde los
-- scripts de administración (scripts/emitir_licencia.mjs) con el usuario dueño.

GRANT USAGE ON SCHEMA public TO licencias_api;

-- Leer licencias. UPDATE sobre una sola columna es el mínimo que PostgreSQL
-- exige para bloquear la fila con SELECT ... FOR UPDATE.
GRANT SELECT, UPDATE (notas) ON licencias TO licencias_api;

GRANT SELECT, INSERT, UPDATE ON activaciones TO licencias_api;
GRANT SELECT, INSERT ON intentos_activacion TO licencias_api;
