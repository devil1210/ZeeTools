import 'package:flutter/material.dart';

import 'app_dimensions.dart';

const appSeedColor = Color(0xFF0073A4); // Color base de ZeePubs

const _radius = BorderRadius.all(Radius.circular(AppRadius.small));
const _roundedShape = RoundedRectangleBorder(borderRadius: _radius);
// Misma altura que los campos de texto.
const _buttonStyle = ButtonStyle(shape: WidgetStatePropertyAll(_roundedShape), visualDensity: VisualDensity.standard, minimumSize: WidgetStatePropertyAll(Size(AppSize.medium, AppSize.medium)));

ThemeData buildAppTheme(ColorScheme colorScheme) {
  // El borde se aclara al pasar el ratón en campos, desplegables y botones con contorno.
  BorderSide outline(Set<WidgetState> states) => switch (states) {
    _ when states.contains(WidgetState.disabled) => BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12)),
    _ when states.contains(WidgetState.error) => BorderSide(color: colorScheme.error, width: states.contains(WidgetState.focused) ? 2 : 1),
    _ when states.contains(WidgetState.focused) => BorderSide(color: colorScheme.primary, width: 2),
    _ when states.contains(WidgetState.hovered) => BorderSide(color: colorScheme.onSurface),
    _ => BorderSide(color: colorScheme.outline),
  };

  return ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    colorScheme: colorScheme,
    // Misma altura para campos de texto y desplegables; el relleno transparente
    // habilita el sombreado al pasar el ratón. La etiqueta queda siempre arriba
    // para que la sugerencia o el estado del campo se vean sin enfocarlo.
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.transparent,
      hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
      border: WidgetStateInputBorder.resolveWith((states) => OutlineInputBorder(borderRadius: _radius, borderSide: outline(states))),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppPadding.medium + AppPadding.small, vertical: AppPadding.medium + AppPadding.small),
    ),
    listTileTheme: const ListTileThemeData(
      shape: _roundedShape,
      contentPadding: EdgeInsets.symmetric(horizontal: AppPadding.medium + AppPadding.small),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(style: _buttonStyle.copyWith(side: WidgetStateProperty.resolveWith(outline))),
    filledButtonTheme: const FilledButtonThemeData(style: _buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle.copyWith(side: WidgetStateProperty.resolveWith(outline))),
    textButtonTheme: const TextButtonThemeData(style: _buttonStyle),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: _buttonStyle),
    menuButtonTheme: const MenuButtonThemeData(style: _buttonStyle),
    popupMenuTheme: const PopupMenuThemeData(position: PopupMenuPosition.under),
  );
}
