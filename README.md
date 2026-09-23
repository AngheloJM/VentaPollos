# Venta Pollos 🍗

App móvil (Android / iOS) de punto de venta para pollería, hecha en Flutter.

- **Base de datos local SQLite** (`sqflite`): productos, categorías, ventas y configuración. Funciona sin internet.
- **Impresión de comandas ESC/POS** en impresoras térmicas de 58 / 80 mm:
  - **Red** (Ethernet/WiFi), modo RAW TCP puerto 9100.
  - **Bluetooth** (`print_bluetooth_thermal`): clásico en Android, BLE en iOS.
- Interfaz Material 3 adaptable: teléfono (carrito en panel inferior) y tablet (carrito lateral).
- **Usuarios con PIN** y dos roles: *Administrador* (todo) y *Cajero* (vender, ver ventas, reimprimir).
- **Panel de administración**: platos y combos (con contenido que se imprime en la comanda), precios,
  categorías, usuarios e impresora.
- **Vista previa del ticket** idéntica a la impresión (misma rejilla de 32/48 columnas).

## Primer uso y seguridad

Al abrir la app por primera vez se pide crear el **administrador** (no existe usuario ni PIN por defecto).

- Los PIN (4 a 8 dígitos) se guardan con **PBKDF2-HMAC-SHA256** y sal aleatoria; nunca en texto plano.
- Tras 5 PIN incorrectos el usuario queda bloqueado 60 segundos.
- Siempre debe existir al menos un administrador activo.
- Si se olvida el PIN del único administrador no hay recuperación: cree un segundo administrador de respaldo.

## Estructura

```
lib/
├── main.dart                     # Arranque y providers
├── app/theme.dart                # Tema visual
├── data/
│   ├── app_database.dart         # Esquema SQLite + datos iniciales
│   └── repositories/             # Acceso a datos (productos, ventas, config)
├── models/                       # Producto, Venta, PrinterConfig
├── providers/                    # Estado: catálogo, carrito, impresora
├── services/
│   ├── auth/pin_hasher.dart      # Hash de PIN
│   └── printing/
│       ├── ticket.dart           # Modelo neutral del ticket (líneas, filas, corte)
│       ├── ticket_formatter.dart # Diseño de comanda, recibo y prueba
│       ├── escpos_renderer.dart  # Ticket -> bytes ESC/POS
│       └── printer_transport.dart# Envío por red (Socket) o Bluetooth
├── screens/
│   ├── auth/                     # Primer uso, login con PIN
│   ├── admin/                    # Platos y combos, categorías, usuarios, impresora
│   └── ...                       # Vender, Ventas
├── widgets/                      # Tarjetas, carrito, vista previa del ticket
└── utils/formato.dart            # Moneda (centavos) y fechas
tool/impresora_virtual.py         # Impresora térmica virtual para la PC
```

Los montos se guardan como **enteros en centavos** para evitar errores de redondeo.

## Puesta en marcha

```bash
flutter pub get
flutter run
```

## Permisos (ya aplicados en `android/` e `ios/`)

**Android** – `android/app/src/main/AndroidManifest.xml`:
`INTERNET`, `BLUETOOTH`, `BLUETOOTH_ADMIN` (≤ API 30), `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `ACCESS_FINE_LOCATION` (≤ API 30).

**iOS** – `ios/Runner/Info.plist`:
`NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`, `NSLocalNetworkUsageDescription`.

## Probar la impresión sin impresora

**1. En la app (modo Pantalla):** *Admin → Impresora → Pantalla*. Al cobrar se muestra la comanda
(y el recibo, si está activado) tal como saldría impresa. En *Ventas* cada pedido tiene **Ver ticket**.

**2. Impresora virtual en la PC:** recibe los mismos bytes ESC/POS que una impresora real y los dibuja
en la terminal.

```bash
python3 tool/impresora_virtual.py --ancho 80            # o --ancho 58
```

En la app: *Admin → Impresora → Red*, IP de la PC (`10.0.2.2` desde el emulador) y puerto `9100`.
Por defecto escucha en toda la red local (`0.0.0.0`) para que llegue desde un celular; si solo usa el
emulador, añada `--host 127.0.0.1`. Con `--guardar carpeta/` guarda cada ticket `.bin`, y
`--archivo ticket.bin` vuelve a mostrar uno guardado.

## Impresoras

- **Red**: asigne IP fija a la impresora (normalmente se imprime con el botón FEED al encender). El teléfono debe estar en la misma red.
- **Bluetooth (Android)**: vincule primero la impresora desde los ajustes del teléfono; luego en *Admin → Impresora → Bluetooth → Buscar impresoras vinculadas*.
- **Bluetooth (iOS)**: solo funcionan impresoras **BLE** (muchas impresoras chinas de 58 mm solo tienen Bluetooth clásico y no funcionan en iPhone; verifique antes de comprar).
- El texto impreso se normaliza a ASCII (sin tildes ni ñ) porque muchas impresoras genéricas no tienen la página de códigos correcta.

## Pendiente / siguientes pasos sugeridos

- Reporte de cierre de caja e impresión del resumen del día.
- Respaldo/exportación de la base de datos.
- Íconos y splash de la app (`flutter_launcher_icons`, `flutter_native_splash`).
