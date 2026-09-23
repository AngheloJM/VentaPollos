// Conexión para los scripts de administración. Lee DATABASE_URL del entorno;
// nunca se escribe la cadena de conexión en el código.
import { Pool } from '@neondatabase/serverless';

export function conectar() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('Defina DATABASE_URL en el entorno (no la escriba en el código).');
    console.error('Ejemplo:  read -rs DATABASE_URL && export DATABASE_URL');
    process.exit(1);
  }
  if (!globalThis.WebSocket) {
    console.error('Se requiere Node 22 o superior (WebSocket global).');
    process.exit(1);
  }
  return new Pool({ connectionString: url });
}
