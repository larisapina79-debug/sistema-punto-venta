
import 'package:flutter/material.dart';

class Search extends StatelessWidget {
  const Search({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Buscar...',
    this.primaryColor = const Color.fromARGB(255, 99, 183, 196),
    this.backgroundColor = const Color(0xFFF8F8F8),
    this.borderColor = const Color(0xFFE0E0E0),
    this.height = 48,
    this.borderRadius = 28,
    this.fontSize = 15,
    this.hintFontSize = 14,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final double height;
  final double borderRadius;
  final double fontSize;
  final double hintFontSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        style: TextStyle(
          color: const Color(0xFF111111),
          fontSize: fontSize,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFF9E9E9E),
            fontSize: hintFontSize,
          ),
          filled: true,
          fillColor: backgroundColor,
          prefixIcon: Icon(
            Icons.search,
            color: primaryColor,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: Icon(
                    Icons.close_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  onPressed: enabled
                      ? () {
                          controller.clear();
                          onChanged('');
                        }
                      : null,
                ),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: primaryColor,
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: borderColor),
          ),
        ),
      ),
    );
  }
}
