import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/utils/either.dart';
import '/common/widgets/confirm_dialog.dart';
import '/features/metadata_editor/data/epub_metadata_repo.dart';
import '/inject_dependencies.dart';
import '../../cubit/epub_templater_cubit.dart';

// El nombre en edición es estado local: teclearlo solo reconstruye esta barra.
class ProfileBar extends StatefulWidget {
  const ProfileBar({super.key});

  @override
  State<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends State<ProfileBar> {
  String _name = '';

  // Un solo EPUB: la plantilla es de un libro.
  Future<void> _import() async {
    final cubit = context.read<EpubTemplaterCubit>();
    final path = (await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      dialogTitle: 'Importar metadatos de un EPUB',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    )).map((f) => f.path).whereType<String>().firstOrNull;
    if (path == null) return;
    final repo = getIt<EpubMetadataRepository>();
    final result = await repo.load(path);
    repo.unload(path);
    result.fold((error) => cubit.notify(error, isError: true), (metadata) => cubit.importMetadata(metadata, p.basename(path)));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final profiles = context.select((EpubTemplaterCubit c) => c.state.profiles);
    final exists = profiles.containsKey(_name.trim());
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium, AppPadding.medium, AppPadding.medium),
      child: Row(
        spacing: AppSpacing.small,
        children: [
          Expanded(
            child: Autocomplete<String>(
              optionsBuilder: (value) {
                final query = value.text.toLowerCase();
                return profiles.keys.where((k) => k.toLowerCase().contains(query));
              },
              onSelected: (selection) => setState(() => _name = selection),
              fieldViewBuilder: (context, controller, focusNode, _) => TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (v) => setState(() => _name = v),
                decoration: const InputDecoration(
                  labelText: 'Perfil de plantilla',
                  hintText: 'Escribe un nombre para guardar o elige uno existente',
                  prefixIcon: Icon(Icons.bookmarks_outlined, size: 20),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Importar metadatos de un EPUB',
            onPressed: _import,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: exists ? 'Sobrescribir perfil' : 'Guardar perfil',
            onPressed: _name.trim().isEmpty ? null : () => cubit.saveProfile(_name),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Cargar perfil',
            onPressed: exists ? () => cubit.loadProfile(_name) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar perfil',
            onPressed: exists
                ? () async {
                    final confirmed = await confirmAction(context, title: 'Eliminar perfil', message: 'Se eliminará el perfil «${_name.trim()}».', confirmLabel: 'Eliminar');
                    if (confirmed) await cubit.deleteProfile(_name);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
