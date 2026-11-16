import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/dates.dart';

/// Form label (Semi Bold 13) above a field with a 7px gap, plus optional
/// helper text (12 muted).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.helperColor,
  });

  final String label;
  final Widget child;
  final String? helper;
  final Color? helperColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label.copyWith(color: c.textPrimary)),
        const SizedBox(height: 7),
        child,
        if (helper != null) ...[
          const SizedBox(height: 7),
          Text(helper!,
              style: AppTypography.caption
                  .copyWith(color: helperColor ?? c.textMuted)),
        ],
      ],
    );
  }
}

BoxDecoration fieldDecoration(BuildContext context, {bool error = false}) {
  final c = context.colors;
  return BoxDecoration(
    color: c.surface,
    borderRadius: AppRadii.buttonRadius,
    border: Border.all(color: error ? c.danger : c.border),
  );
}

/// Text input: surface fill, 1px border, radius 10, min height 50,
/// padding 14, value 15.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.prefixIcon,
    this.inputFormatters,
    this.textInputAction,
    this.error = false,
    this.semanticLabel,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final IconData? prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool error;
  final String? semanticLabel;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: AppTypography.title.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppTypography.title.copyWith(color: c.textMuted),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(prefixIcon, size: 20, color: c.textMuted),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: fieldDecoration(context, error: error),
        alignment: Alignment.centerLeft,
        child: field,
      ),
    );
  }
}

/// Tappable field that looks like an input and shows a value + chevron.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.value,
    required this.onTap,
    this.placeholder = false,
    this.trailing = LucideIcons.chevronDown,
    this.semanticLabel,
  });

  final String value;
  final VoidCallback? onTap;
  final bool placeholder;
  final IconData? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AppTypography.title.copyWith(
                        color: placeholder ? c.textMuted : c.textPrimary,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Icon(trailing, size: 18, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown-style select backed by a bottom sheet of options.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.title,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final String? title;

  @override
  Widget build(BuildContext context) => AppPickerField(
        value: labelOf(value),
        semanticLabel: title,
        onTap: () async {
          final picked = await showOptionSheet<T>(
            context,
            title: title,
            options: options,
            labelOf: labelOf,
            selected: value,
          );
          if (picked != null) onChanged(picked);
        },
      );
}

Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  String? title,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(title,
                    style: AppTypography.sectionTitle
                        .copyWith(color: c.textPrimary)),
              ),
            for (final o in options)
              ListTile(
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.buttonRadius),
                title: Text(labelOf(o),
                    style: AppTypography.title.copyWith(color: c.textPrimary)),
                trailing: o == selected
                    ? Icon(LucideIcons.check, size: 18, color: c.textPrimary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(o),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Optional date field: shows "Not set" when null; never infers a date.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowClear = true,
    this.suffix,
    this.label,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  /// Appended after the date ("· you entered").
  final String? suffix;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Not set'
        : '${AppDates.long(value!)}${suffix == null ? '' : ' · $suffix'}';
    return Row(
      children: [
        Expanded(
          child: AppPickerField(
            value: text,
            semanticLabel: label,
            trailing: LucideIcons.calendar,
            onTap: () async {
              final now = AppDates.today();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) onChanged(picked);
            },
          ),
        ),
        if (allowClear && value != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Clear date',
            onPressed: () => onChanged(null),
            icon: Icon(LucideIcons.x, size: 20, color: context.colors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Numeric input formatter: digits with one decimal separator, no sign.
final quantityInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];
