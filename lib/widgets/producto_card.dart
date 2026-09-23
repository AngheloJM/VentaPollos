import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../providers/carrito_provider.dart';
import '../utils/formato.dart';

class ProductoCard extends StatelessWidget {
  final Producto producto;
  const ProductoCard({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cantidad = context.select<CarritoProvider, int>(
        (c) => c.cantidadDe(producto));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.read<CarritoProvider>().agregar(producto);
        },
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tema.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Text(producto.emoji,
                          style: const TextStyle(fontSize: 38)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  dinero(producto.precio),
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: tema.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (cantidad > 0)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tema.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('x$cantidad',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }
}
