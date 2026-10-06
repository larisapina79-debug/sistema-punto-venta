import 'package:flutter/material.dart';

const _green = Color(0xFF0F6B1F);

class EditButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const EditButton({
    super.key,
    required this.onPressed,
    this.text = 'Editar',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 35,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
