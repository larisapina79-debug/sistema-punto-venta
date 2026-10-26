import 'package:flutter/material.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _kSoftBg = Color(0xFFECF6F8);
const Color _kPressedBg = Color(0xFFD9E2E4);

class NuevoButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const NuevoButton({
    super.key,
    required this.onPressed,
    this.text = 'Registrar',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        elevation: 0,
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 13,
        ),
        side: const BorderSide(color: _kGreen, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return _kPressedBg;
          }
          return _kSoftBg;
        }),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}