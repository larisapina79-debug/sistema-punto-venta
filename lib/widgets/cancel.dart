import 'package:flutter/material.dart';

const _red = Color(0xFFF4512A);

class CancelButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final double? width;

  const CancelButton({
    super.key,
    required this.onPressed,
    this.text = 'Cancelar',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 180,
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(
            Colors.white,
          ),
          foregroundColor: const WidgetStatePropertyAll(
            _red,
          ),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(
                color: _red,
                width: 1,
              ),
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            Color(0xFFFFEBE7),
          ),
        ),
        child: Text(
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

