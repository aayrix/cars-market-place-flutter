import 'package:flutter/services.dart';

String formatGroupedInt(int? value) {
  if (value == null) return '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

int? parseGroupedInt(String value) =>
    int.tryParse(value.replaceAll(',', '').trim());

class CommaSeparatedNumberInputFormatter extends TextInputFormatter {
  const CommaSeparatedNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    final text = grouped.toString();

    final inputOffset = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final digitsBeforeCursor = newValue.text
        .substring(0, inputOffset)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var cursor = 0;
    var countedDigits = 0;
    while (cursor < text.length && countedDigits < digitsBeforeCursor) {
      if (text.codeUnitAt(cursor) >= 48 && text.codeUnitAt(cursor) <= 57) {
        countedDigits++;
      }
      cursor++;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
