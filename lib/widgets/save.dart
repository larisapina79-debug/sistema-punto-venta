import 'package:flutter/material.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _kSoftBg = Color(0xFFECF6F8);
const Color _kPressedBg = Color(0xFFD9E2E4);

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
                return _kSoftBg.withValues(alpha: 0.6);
              }
              if (states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.hovered)) {
                return _kPressedBg;
              }
              return _kSoftBg;
            },
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.black),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          side: WidgetStateProperty.resolveWith<BorderSide>(
            (states) {
              final disabled = states.contains(WidgetState.disabled);
              return BorderSide(
                color: disabled ? _kGreen.withValues(alpha: 0.5) : _kGreen,
                width: 1.5,
              );
            },
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: loading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: _kGreen,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}