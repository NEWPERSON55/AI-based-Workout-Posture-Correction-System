import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Styled text field matching the Stitch KINETIC design.
class KineticTextField extends StatelessWidget {
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final String? label;
  final TextEditingController? controller;

  const KineticTextField({
    super.key,
    required this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.label,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.inter(
              color: AppColors.onSurface,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Icon(
                        prefixIcon,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              enabledBorder: const UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.transparent, width: 2),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.secondary, width: 2),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
