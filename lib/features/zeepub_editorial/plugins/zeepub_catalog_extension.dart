import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/inject_dependencies.dart';
import '../../plugins/domain/plugin_extension.dart';
import '../../plugins/domain/plugin_manifest.dart';
import '../presentation/cubit/zeepub_editorial_cubit.dart';
import '../presentation/views/modular/zeepub_catalog_view.dart';

/// Extensión de ZeeTools para el Catálogo de Libros y Novelas de ZeePub.
class ZeepubCatalogExtension implements ZeeToolsPluginExtension {
  const ZeepubCatalogExtension();

  @override
  String get id => 'zeepub_catalog';

  @override
  Widget buildView(BuildContext context, PluginManifest manifest) {
    return BlocProvider(
      create: (_) => getIt<ZeepubEditorialCubit>(),
      child: const ZeepubCatalogView(),
    );
  }
}
