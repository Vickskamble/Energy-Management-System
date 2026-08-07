import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLines;
  final int? maxLength;
  final int? minLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon != null
            ? InkWell(onTap: onSuffixTap, child: Icon(suffixIcon, size: 20))
            : null,
      ),
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  final T initialValue;
  final List<T> items;
  final String Function(T) itemLabel;
  final String label;
  final IconData? prefixIcon;
  final void Function(T?) onChanged;

  const AppDropdown({
    super.key,
    required this.initialValue,
    required this.items,
    required this.itemLabel,
    required this.label,
    this.prefixIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem(value: item, child: Text(itemLabel(item))),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class AppDatePicker extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const AppDatePicker({
    super.key,
    required this.controller,
    required this.label,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2030),
        );
        if (date != null) {
          controller.text =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }
}
