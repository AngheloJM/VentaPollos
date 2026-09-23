# Venta Pollos 🍗

App móvil (Android / iOS) de punto de venta para pollería, hecha en Flutter.

- **Base de datos local SQLite** (`sqflite`): productos, categorías, ventas y configuración. Funciona sin internet.
- **Impresión de comandas ESC/POS** en impresoras térmicas de 58 / 80 mm:
  - **Red** (Ethernet/WiFi), modo RAW TCP puerto 9100.
  - **Bluetooth** (`print_bluetooth_thermal`): clásico en Android, BLE en iOS.
- Interfaz Material 3 adaptable: teléfono (carrito en panel inferior) y tablet (carrito lateral).

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
├── services/printing/
│   ├── ticket_builder.dart       # Comanda de cocina y recibo (ESC/POS)
│   └── printer_transport.dart    # Envío por red (Socket) o Bluetooth
├── screens/                      # Vender, Ventas, Productos, Ajustes
├── widgets/                      # Tarjeta de producto, panel de carrito
└── utils/formato.dart            # Moneda (centavos) y fechas
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

## Impresoras

- **Red**: asigne IP fija a la impresora (normalmente se imprime con el botón FEED al encender). El teléfono debe estar en la misma red.
- **Bluetooth (Android)**: vincule primero la impresora desde los ajustes del teléfono; luego en *Ajustes → Buscar impresoras vinculadas*.
- **Bluetooth (iOS)**: solo funcionan impresoras **BLE** (muchas impresoras chinas de 58 mm solo tienen Bluetooth clásico y no funcionan en iPhone; verifique antes de comprar).
- El texto impreso se normaliza a ASCII (sin tildes ni ñ) porque muchas impresoras genéricas no tienen la página de códigos correcta.

## Pendiente / siguientes pasos sugeridos

- Gestión de categorías desde la app.
- Reporte de cierre de caja e impresión del resumen del día.
- Respaldo/exportación de la base de datos.
- Íconos y splash de la app (`flutter_launcher_icons`, `flutter_native_splash`).
