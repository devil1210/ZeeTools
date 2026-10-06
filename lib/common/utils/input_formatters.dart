import 'dart:math';

import 'package:flutter/services.dart';

// Números con decimales opcionales, p. ej. 3 o 3.5.
final decimalNumberFormatter = TextInputFormatter.withFunction((oldValue, newValue) => RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text) ? newValue : oldValue);

// Guiones del template para el ISBN: 978-XX-XXXX-XXX-X y XX-XXXX-XXX-X.
const isbn13Groups = [3, 2, 4, 3, 1];
const isbn10Groups = [2, 4, 3, 1];

String formatIsbn(String text, List<int> groups) {
  final total = groups.reduce((a, b) => a + b);
  final chars = text.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
  final digits = chars.substring(0, min(chars.length, total));
  final parts = <String>[];
  var start = 0;
  for (final size in groups) {
    if (start >= digits.length) break;
    parts.add(digits.substring(start, min(start + size, digits.length)));
    start += size;
  }
  return parts.join('-');
}

TextInputFormatter isbnFormatter(List<int> groups) => TextInputFormatter.withFunction((oldValue, newValue) {
  final text = formatIsbn(newValue.text, groups);
  return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
});
