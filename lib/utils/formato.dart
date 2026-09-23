import 'package:intl/intl.dart';

/// Los montos se guardan en centavos (int) para evitar errores de redondeo.
const String moneda = 'Bs';

String dinero(int centavos) => '$moneda ${(centavos / 100).toStringAsFixed(2)}';

/// Convierte "12.50" o "12,50" a centavos. Devuelve null si no es válido.
int? parsearDinero(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  final valor = double.tryParse(limpio);
  if (valor == null || valor < 0) return null;
  return (valor * 100).round();
}

String fechaHora(DateTime f) => DateFormat('dd/MM/yyyy HH:mm', 'es').format(f);
String fechaLarga(DateTime f) =>
    DateFormat("EEEE d 'de' MMMM", 'es').format(f);
String hora(DateTime f) => DateFormat('HH:mm', 'es').format(f);
