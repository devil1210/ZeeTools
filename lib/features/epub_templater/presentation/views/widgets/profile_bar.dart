import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/utils/either.dart';
import '/common/utils/open_external.dart';
import '/common/widgets/confirm_dialog.dart';
import '/features/metadata_editor/data/epub_metadata_repo.dart';
import '/inject_dependencies.dart';
import '../../cubit/epub_templater_cubit.dart';

// El nombre en edición es estado local: teclearlo solo reconstruye esta barra.
class const ProfileBar({super.key}) extends StatefulWidget {
  @override
  State<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends State<ProfileBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _menu = MenuController();
  String _name = '';

  @override
  void initState() {
    super.initState();
    // Al entrar en el campo vacío se despliegan todos los perfiles.
    _focus.addListener(() {
      if (_focus.hasFocus && _name.trim().isEmpty && !_menu.isOpen) _menu.open();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final query = _name.trim().toLowerCase();
                final matches = profiles.keys.where((k) => k.toLowerCase().contains(query)).toList();
                return MenuAnchor(
                  controller: _menu,
                  childFocusNode: _focus,
                  style: MenuStyle(minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0))),
                  menuChildren: [
                    for (final name in matches)
                      MenuItemButton(
                        onPressed: () {
                          _controller.text = name;
                          setState(() => _name = name);
                        },
                        child: Text(name),
                      ),
                    if (matches.isEmpty) const MenuItemButton(child: Text('Ningún perfil coincide')),
                  ],
                  builder: (context, _, _) => TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onTap: () => _menu.isOpen ? null : _menu.open(),
                    onChanged: (v) {
                      setState(() => _name = v);
                      if (!_menu.isOpen) _menu.open();
                    },
                    decoration: InputDecoration(
                      labelText: 'Perfil de plantilla',
                      hintText: 'Escribe un nombre para guardar o elige uno existente',
                      prefixIcon: const Icon(Icons.bookmarks_outlined, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Perfiles guardados',
                        icon: const Icon(Icons.arrow_drop_down),
                        onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restablecer todo',
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Restablecer todo',
                message: 'Las secciones, los metadatos y las fuentes vuelven a los iniciales; se pierde lo que no esté guardado en un perfil.',
                confirmLabel: 'Restablecer',
              );
              if (confirmed) cubit.resetProject();
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Abrir la carpeta de perfiles',
            onPressed: () async {
              await Directory(cubit.profilesDirectory).create(recursive: true);
              await openExternal(cubit.profilesDirectory);
            },
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
