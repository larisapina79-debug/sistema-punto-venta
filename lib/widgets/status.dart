import 'package:flutter/material.dart';

const _green = Color(0xFF0F6B1F);
const _red = Color(0xFFF4512A);

class StatusSwitch extends StatelessWidget {
  final bool activo;
  final String? mensajeEstado;
  final bool mostrandoMensajeEstado;
  final bool puedeCambiar;
  final ValueChanged<bool>? onChanged;

  const StatusSwitch({
    super.key,
    required this.activo,
    this.mensajeEstado,
    this.mostrandoMensajeEstado = false,
    this.puedeCambiar = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
  final mensaje = mensajeEstado?.toLowerCase() ?? '';

final mensajeEsActivo =
    mensaje.contains('activado') &&
    !mensaje.contains('desactivado');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: mostrandoMensajeEstado ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: EdgeInsets.only(
              bottom: mostrandoMensajeEstado ? 8 : 0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: mensajeEsActivo
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mensajeEsActivo
                    ? const Color(0xFFB7DDBA)
                    : const Color(0xFFFFC5C5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mensajeEsActivo
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 17,
                  color: mensajeEsActivo ? _green : _red,
                ),
                const SizedBox(width: 7),
                Text(
                  mensajeEstado ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mensajeEsActivo ? _green : _red,
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: activo
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activo
                  ? const Color(0xFFB7DDBA)
                  : const Color(0xFFFFC5C5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activo
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                size: 20,
                color: activo ? _green : _red,
              ),
              const SizedBox(width: 8),
              Text(
                activo ? 'Activado' : 'Desactivado',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: activo ? _green : _red,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch(
                    value: activo,
                    activeTrackColor: _green,
                    activeThumbColor: Colors.white,
                    inactiveTrackColor:
                        _red.withValues(alpha: 0.35),
                    inactiveThumbColor: Colors.white,
                    trackOutlineColor:
                        WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                    onChanged:
                        puedeCambiar ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
