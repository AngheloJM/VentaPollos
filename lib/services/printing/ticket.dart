/// Representación neutral de un ticket. La misma lista de líneas se usa
/// para generar ESC/POS y para la vista previa en pantalla, así lo que se
/// ve es lo que se imprime.
library;

enum Alineacion { izquierda, centro, derecha }

sealed class LineaTicket {
  const LineaTicket();
}

class TextoTicket extends LineaTicket {
  final String texto;
  final Alineacion alineacion;
  final bool negrita;
  final bool altoDoble;
  final bool anchoDoble;

  const TextoTicket(
    this.texto, {
    this.alineacion = Alineacion.izquierda,
    this.negrita = false,
    this.altoDoble = false,
    this.anchoDoble = false,
  });
}

class ColumnaTicket {
  final String texto;

  /// Ancho en doceavos del papel (la suma de la fila debe ser 12).
  final int ancho;
  final Alineacion alineacion;
  final bool negrita;
  final bool altoDoble;

  const ColumnaTicket(
    this.texto,
    this.ancho, {
    this.alineacion = Alineacion.izquierda,
    this.negrita = false,
    this.altoDoble = false,
  });
}

class FilaTicket extends LineaTicket {
  final List<ColumnaTicket> columnas;
  FilaTicket(this.columnas)
      : assert(columnas.fold<int>(0, (s, c) => s + c.ancho) == 12);
}

class SeparadorTicket extends LineaTicket {
  final String caracter;
  const SeparadorTicket([this.caracter = '-']);
}

class AvanceTicket extends LineaTicket {
  final int lineas;
  const AvanceTicket([this.lineas = 1]);
}

class CorteTicket extends LineaTicket {
  const CorteTicket();
}

class TicketDoc {
  final String titulo;
  final List<LineaTicket> lineas;
  const TicketDoc(this.titulo, this.lineas);
}

/// Caracteres por línea con la fuente A estándar.
int columnasPapel(int anchoMm) => anchoMm == 58 ? 32 : 48;
