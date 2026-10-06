
import 'package:flutter/material.dart';

const _green = Color(0xFF0F6B1F);

class GuardarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String text;
  final double? width;

  const GuardarButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.text = 'Guardar',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 180,
      height: 44,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(WidgetState.disabled)) {
                return _green.withValues(alpha: 0.55);
              }

              if (states.contains(WidgetState.pressed)) {
                return const Color(0xFF0A5217);
              }

              return _green;
            },
          ),
          foregroundColor: const WidgetStatePropertyAll(
            Colors.white,
          ),
          elevation: WidgetStateProperty.resolveWith<double>(
            (states) {
              return states.contains(WidgetState.pressed) ? 1 : 3;
            },
          ),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.18),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(
                color: Color(0xFF2E9E4F),
              ),
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

