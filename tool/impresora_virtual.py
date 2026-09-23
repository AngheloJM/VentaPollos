#!/usr/bin/env python3
"""Impresora térmica virtual para pruebas.

Escucha en TCP (puerto 9100, como una impresora de red real), interpreta los
comandos ESC/POS que envía la app y muestra en la terminal cómo saldría el
ticket impreso.

Uso:
    python3 tool/impresora_virtual.py                 # escucha en 0.0.0.0:9100, 80 mm
    python3 tool/impresora_virtual.py --ancho 58      # papel de 58 mm (32 columnas)
    python3 tool/impresora_virtual.py --guardar tickets/   # además guarda los .bin
    python3 tool/impresora_virtual.py --archivo ticket.bin # interpreta un archivo

En la app: Admin -> Impresora -> Red, IP de esta PC (o 10.0.2.2 desde el
emulador) y puerto 9100.
"""

import argparse
import datetime
import os
import socket
import sys

ESC, GS, FS, LF = 0x1B, 0x1D, 0x1C, 0x0A

NEGRITA = "\033[1m"
RESET = "\033[0m"
GRIS = "\033[90m"

# Cantidad de bytes de argumento de los comandos de longitud fija.
ARGS_ESC = {
    ord("@"): 0, ord("!"): 1, ord("-"): 1, ord("2"): 0, ord("3"): 1,
    ord("E"): 1, ord("G"): 1, ord("M"): 1, ord("R"): 1, ord("V"): 1,
    ord("a"): 1, ord("d"): 1, ord("J"): 1, ord("t"): 1, ord("{"): 1,
    ord("r"): 1, ord("p"): 3, ord("c"): 2, ord("B"): 2, ord("$"): 2,
    ord("\\"): 2, ord(" "): 1,
}
ARGS_GS = {
    ord("!"): 1, ord("B"): 1, ord("H"): 1, ord("L"): 2, ord("W"): 2,
    ord("f"): 1, ord("h"): 1, ord("w"): 1, ord("b"): 1, ord("a"): 1,
}
ARGS_FS = {ord("&"): 0, ord("."): 0, ord("!"): 1, ord("C"): 1}

# ASCII -> formas de ancho completo, para simular letra de ancho doble.
def ancho_doble(c):
    if c == " ":
        return "　"
    if "!" <= c <= "~":
        return chr(ord(c) - 0x21 + 0xFF01)
    return c


class Interprete:
    # La fuente A mide 12 puntos de ancho: 576 puntos = 48 col, 384 = 32 col.
    PUNTOS_POR_COLUMNA = 12

    def __init__(self, columnas):
        self.columnas = columnas
        self.salida = []
        self.reiniciar_estilo()
        self._nueva_linea()

    def reiniciar_estilo(self):
        self.alineacion = 0
        self.negrita = False
        self.ancho = 1
        self.alto = 1

    def _nueva_linea(self):
        self.celdas = {}  # columna -> (caracter, negrita, ancho, alto)
        self.cursor = 0
        self.posicionada = False  # usó posición absoluta (ESC $)

    def _emitir(self, forzar=False):
        if not self.celdas and not forzar:
            return
        texto, alto, col = [], 1, 0
        for c in sorted(self.celdas):
            ch, negrita, ancho, h = self.celdas[c]
            if c < col:
                continue
            texto.append(" " * (c - col))
            txt = ancho_doble(ch) if ancho > 1 else ch
            texto.append(f"{NEGRITA}{txt}{RESET}" if negrita else txt)
            col, alto = c + ancho, max(alto, h)
        relleno = 0
        if not self.posicionada:
            espacio = max(self.columnas - col, 0)
            relleno = {0: 0, 1: espacio // 2, 2: espacio}.get(self.alineacion, 0)
        linea = (" " * relleno + "".join(texto)).rstrip()
        if alto > 1:
            linea += f"  {GRIS}(alto x{alto}){RESET}"
        self.salida.append(linea)
        self._nueva_linea()

    def _caracter(self, c):
        if self.cursor + self.ancho > self.columnas:  # la impresora corta la línea
            self._emitir()
        self.celdas[self.cursor] = (c, self.negrita, self.ancho, self.alto)
        self.cursor += self.ancho

    def procesar(self, datos):
        i, n = 0, len(datos)
        while i < n:
            b = datos[i]
            if b == LF:
                self._emitir(forzar=True)
                i += 1
            elif b == 0x0D:
                i += 1
            elif b == ESC and i + 1 < n:
                cmd = datos[i + 1]
                arg = datos[i + 2] if i + 2 < n else 0
                if cmd == ord("@"):
                    self.reiniciar_estilo()
                elif cmd == ord("a"):
                    self.alineacion = arg % 48 if arg >= 48 else arg
                elif cmd == ord("E"):
                    self.negrita = bool(arg & 1)
                elif cmd == ord("!"):
                    self.negrita = bool(arg & 0x08)
                    self.alto = 2 if arg & 0x10 else 1
                    self.ancho = 2 if arg & 0x20 else 1
                elif cmd == ord("$") and i + 3 < n:  # posición absoluta
                    puntos = datos[i + 2] + datos[i + 3] * 256
                    self.cursor = puntos // self.PUNTOS_POR_COLUMNA
                    # ESC $ 0 no anula la alineación; las columnas (> 0) sí.
                    self.posicionada = self.posicionada or puntos > 0
                elif cmd in (ord("d"), ord("J")):
                    self._emitir()
                    lineas = arg if cmd == ord("d") else max(arg // 30, 1)
                    self.salida.extend([""] * lineas)
                elif cmd == ord("*"):  # imagen de bits: m nL nH datos
                    m, nl, nh = datos[i + 2], datos[i + 3], datos[i + 4]
                    ancho = nl + nh * 256
                    i += 5 + ancho * (3 if m in (32, 33) else 1)
                    self.salida.append(f"{GRIS}[imagen]{RESET}")
                    continue
                i += 2 + ARGS_ESC.get(cmd, 1)
            elif b == GS and i + 1 < n:
                cmd = datos[i + 1]
                arg = datos[i + 2] if i + 2 < n else 0
                if cmd == ord("!"):
                    self.ancho = ((arg >> 4) & 0x0F) + 1
                    self.alto = (arg & 0x0F) + 1
                    i += 3
                elif cmd == ord("V"):  # corte
                    self._emitir()
                    self.salida.append(f"{GRIS}{'✂ - ' * (self.columnas // 4)}{RESET}")
                    i += 4 if arg in (65, 66) else 3
                elif cmd == ord("v") and datos[i + 2] == ord("0"):  # imagen raster
                    xl, xh, yl, yh = datos[i + 4:i + 8]
                    i += 8 + (xl + xh * 256) * (yl + yh * 256)
                    self.salida.append(f"{GRIS}[imagen]{RESET}")
                elif cmd == ord("(") and i + 4 < n:  # QR y otros: GS ( fn pL pH ...
                    longitud = datos[i + 3] + datos[i + 4] * 256
                    i += 5 + longitud
                elif cmd == ord("k"):  # código de barras
                    m = datos[i + 2]
                    if m <= 6:
                        fin = datos.find(b"\x00", i + 3)
                        i = fin + 1 if fin >= 0 else n
                    else:
                        i += 4 + datos[i + 3]
                    self.salida.append(f"{GRIS}[código de barras]{RESET}")
                else:
                    i += 2 + ARGS_GS.get(cmd, 1)
            elif b == FS and i + 1 < n:
                i += 2 + ARGS_FS.get(datos[i + 1], 0)
            elif b >= 0x20:
                self._caracter(chr(b) if b < 0x80 else bytes([b]).decode("cp437", "replace"))
                i += 1
            else:
                i += 1
        self._emitir()
        return self.salida


def mostrar(datos, columnas, origen):
    borde = "─" * (columnas + 2)
    print(f"\n{GRIS}Ticket de {origen} · {len(datos)} bytes · "
          f"{datetime.datetime.now():%H:%M:%S}{RESET}")
    print(f"┌{borde}┐")
    for linea in Interprete(columnas).procesar(datos):
        print(f"  {linea}")
    print(f"└{borde}┘", flush=True)


def servidor(args, columnas):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((args.host, args.puerto))
        s.listen()
        print(f"Impresora virtual escuchando en {args.host}:{args.puerto} "
              f"(papel {args.ancho} mm, {columnas} columnas). Ctrl+C para salir.")
        while True:
            conexion, direccion = s.accept()
            with conexion:
                conexion.settimeout(10)
                partes = []
                try:
                    while True:
                        bloque = conexion.recv(4096)
                        if not bloque:
                            break
                        partes.append(bloque)
                except socket.timeout:
                    pass
            datos = b"".join(partes)
            if not datos:
                continue
            if args.guardar:
                os.makedirs(args.guardar, exist_ok=True)
                ruta = os.path.join(
                    args.guardar, f"ticket_{datetime.datetime.now():%Y%m%d_%H%M%S_%f}.bin")
                with open(ruta, "wb") as f:
                    f.write(datos)
            mostrar(datos, columnas, direccion[0])


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--host", default="0.0.0.0",
                   help="interfaz de escucha (0.0.0.0 = toda la red local)")
    p.add_argument("--puerto", type=int, default=9100)
    p.add_argument("--ancho", type=int, choices=[58, 80], default=80,
                   help="ancho del papel en mm")
    p.add_argument("--guardar", metavar="CARPETA",
                   help="guardar cada ticket recibido como .bin")
    p.add_argument("--archivo", help="interpretar un archivo .bin y salir")
    args = p.parse_args()
    columnas = 32 if args.ancho == 58 else 48

    if args.archivo:
        with open(args.archivo, "rb") as f:
            mostrar(f.read(), columnas, args.archivo)
        return
    try:
        servidor(args, columnas)
    except KeyboardInterrupt:
        print("\nImpresora virtual detenida.")
    except OSError as e:
        sys.exit(f"No se pudo abrir el puerto {args.puerto}: {e}")


if __name__ == "__main__":
    main()
