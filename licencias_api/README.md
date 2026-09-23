# API de licencias – Venta Pollos

Cloudflare Worker que activa licencias de la app contra una base PostgreSQL en Neon.
La app **nunca** se conecta a la base: solo llama a esta API una vez, al activar.

## Flujo

1. La app envía `POST /v1/activar` con la clave y el SHA-256 del `ANDROID_ID`.
2. La API valida la clave (se guarda solo su SHA-256), aplica las reglas y registra el dispositivo.
3. Devuelve un **token firmado con Ed25519**. La app guarda el token y el hash de la clave, y
   verifica la firma **sin internet** con la clave pública. Solo vuelve a consultar cuando la
   licencia expira.

| Caso | Respuesta |
|---|---|
| Primera activación | `200 activada` + token (la beta vence `dias_validez` después) |
| Mismo celular (reinstalación, datos borrados) | `200 reactivada`, **mismo** vencimiento |
| Beta vencida (aunque reinstalen) | `403 expirada` |
| Otro celular con el cupo lleno | `409 en_uso` |
| Clave inexistente / revocada | `403 invalida` / `403 revocada` |
| 10 fallos desde la misma IP en 15 min | `429 demasiados_intentos` |

### Petición

```json
POST /v1/activar
{ "clave": "VP-7K2Q-M9XD-4TRA-HB3W", "dispositivo": "<sha256 hex del ANDROID_ID>",
  "modelo": "Pixel 7", "version_app": "1.0.0" }
```

### Token

`base64url(contenido).base64url(firma)`, con contenido:

```json
{ "v": 1, "prod": "venta_pollos", "lic": 1, "tipo": "beta", "disp": "<sha256>",
  "clave": "<sha256 de la clave>", "iat": 1790000000, "exp": 1791296000 }
```

`exp: null` = licencia perpetua.

## Puesta en marcha

1. **Esquema** (una vez, usuario dueño): `sql/001_esquema.sql`.
2. **Usuario limitado para la API**: crear el rol `licencias_api` en la consola de Neon y ejecutar
   `sql/002_permisos_api.sql`.
3. **Claves de firma**: `npm run claves-firma`. La privada queda en `~/.config/ventapollos/`
   (permisos 600); la pública se imprime y va en la app.
4. **Secretos en Cloudflare** (*Settings → Variables and Secrets*, tipo **Secret**):
   - `DATABASE_URL`: cadena de conexión del rol `licencias_api`.
   - `LICENCIA_CLAVE_PRIVADA`: contenido de `~/.config/ventapollos/licencia_clave_privada.b64`.
5. **Despliegue**: Cloudflare Workers Builds publica al hacer push a `main`
   (raíz `licencias_api`, build `npm ci`, deploy `npx wrangler deploy`).

**Nunca** ponga secretos en `wrangler.jsonc` ni en el repositorio (es público).

## Administración (desde su PC)

Los scripts leen `DATABASE_URL` del entorno (use el usuario dueño, no el de la API):

```bash
read -rs DATABASE_URL && export DATABASE_URL     # pega la cadena sin que se vea ni quede en el historial

npm run emitir -- --tipo beta --dias 15 --cliente "Pollería X"
npm run emitir -- --tipo completa --cliente "Pollería X"
npm run liberar -- --licencia 1                  # ver dispositivos
npm run liberar -- --licencia 1 --activacion 3   # liberar uno (celular nuevo)
npm run liberar -- --licencia 1 --revocar        # revocar la licencia
```

La clave se muestra **una sola vez** al emitirla; en la base solo queda su hash.

## Desarrollo

```bash
npm install
npm test          # reglas, validación, firma y límites (sin base real)
npm run dev       # Worker local en http://localhost:8787
```
