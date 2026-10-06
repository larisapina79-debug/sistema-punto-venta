import 'package:flutter/material.dart';

const _btnGreen = Color(0xFF0F6B1F);

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
        backgroundColor: _btnGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.20),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(
          color: Color(0xFF2E9E4F),
          width: 1,
        ),
        overlayColor: Colors.white.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              size: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}