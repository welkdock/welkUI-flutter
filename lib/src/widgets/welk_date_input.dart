import 'package:flutter/material.dart';

import 'welk_date_picker.dart';

/// A controlled date field with a styled, dismissible mobile calendar dialog.
///
/// The calendar fits all seven Monday-to-Sunday columns to the dialog width.
/// Tap its heading to choose a year and month without stepping month by month.
/// The calendar button opens the popup; typing never unexpectedly opens a
/// dialog. Invalid or out-of-range text is not emitted. Null [onChanged]
/// disables both the editor and the popup action.
class WelkDateInput extends StatelessWidget {
  const WelkDateInput({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.minDate,
    this.maxDate,
    this.initialDisplayDate,
    this.isRequired = false,
    this.validator,
    this.focusNode,
    this.autofocus = false,
    this.overRideDarkMode,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  /// Month initially displayed for an empty field. Defaults to today.
  final DateTime? initialDisplayDate;
  final bool isRequired;
  final String? Function(DateTime?)? validator;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? overRideDarkMode;

  @override
  Widget build(BuildContext context) => PickerDateControl(
    overRideDarkMode: overRideDarkMode,
    label: label,
    value: value,
    onChanged: onChanged,
    minDate: minDate,
    maxDate: maxDate,
    initialDisplayDate: initialDisplayDate,
    isRequired: isRequired,
    validator: validator,
    focusNode: focusNode,
    autofocus: autofocus,
    popup: true,
  );
}
