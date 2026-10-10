import 'package:flutter/material.dart';
import 'plugin_manifest.dart';

/// Interfaz para extensiones registradas en ZeeTools.
/// Permite que un plugin con este ID renderice vistas nativas Flutter de forma segura.
abstract class ZeeToolsPluginExtension {
  String get id;
  Widget buildView(BuildContext context, PluginManifest manifest);
}
