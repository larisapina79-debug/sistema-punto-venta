import 'package:flutter/material.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _kSoftBg = Color(0xFFECF6F8);
const Color _kPressedBg = Color(0xFFD9E2E4);

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
          foregroundColor: Colors.black,
          elevation: 0,
          padding: EdgeInsets.zero,
          splashFactory: NoSplash.splashFactory,
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}