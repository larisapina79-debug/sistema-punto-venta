import 'package:flutter/material.dart';

const _green = Color(0xFF0F6B1F);

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 54,
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
              if (states.contains(WidgetState.pressed)) {
                return 1;
              }

              return 3;
            },
          ),

          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.22),
          ),

          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
          ),

          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(
                color: Color(0xFF2E9E4F),
                width: 1,
              ),
            ),
          ),

          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues (alpha: 0.08),
          ),
        ),

        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),

          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  key: const ValueKey('text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
