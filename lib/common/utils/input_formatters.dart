import 'package:flutter/services.dart';

// Números con decimales opcionales, p. ej. 3 o 3.5.
final decimalNumberFormatter = TextInputFormatter.withFunction((oldValue, newValue) => RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text) ? newValue : oldValue);
