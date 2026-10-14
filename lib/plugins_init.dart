import 'features/plugins/data/plugin_registry.dart';
import 'features/zeepub_editorial/zeepub_plugins.dart';

/// Punto de extensión para registrar complementos y paquetes en ZeeTools.
///
/// Todas las extensiones que implementen `ZeeToolsPluginExtension`
/// se registran aquí para integrarse automáticamente en el Dashboard,
/// la pantalla de configuración y el sistema de navegación.
void registerCustomPlugins(PluginRegistry registry) {
  registerZeepubPlugins(registry);
}
