import 'package:flutter/material.dart';

const Color _kGreen = Color.fromARGB(255, 99, 183, 196);
const Color _kSoftBg = Color(0xFFECF6F8);
const Color _kPressedBg = Color(0xFFD9E2E4);

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
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
          ),
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _kGreen,
                  ),
                )
              : Text(
                  text,
                  key: const ValueKey('text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}