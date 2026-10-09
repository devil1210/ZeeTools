import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/utils/list_toggle.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/field_grid.dart';
import '/common/widgets/field_group.dart';
import '/common/widgets/file_drop_button.dart';
import '/common/widgets/form_page.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/outlined_dropdown.dart';
import '/common/widgets/selection_pill.dart';
import '../../../data/system_fonts.dart';
import '../../../domain/embedded_font.dart';
import '../../cubit/epub_templater_cubit.dart';

Future<String?> _pickSystemFont(BuildContext context) {
  final fonts = context.read<EpubTemplaterCubit>().systemFonts();
  return showDialog<String>(
    context: context,
    builder: (_) => _SystemFontPicker(fonts: fonts),
  );
}

class const FontsForm({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final fonts = context.select((EpubTemplaterCubit c) => c.state.project.fonts);
    return FormPage(
      sections: [
        FormSection(
          title: 'Fuentes incrustadas',
          icon: Icons.font_download_outlined,
          children: [
            for (final (i, font) in fonts.indexed)
              _FontCard(
                key: ValueKey('$i-${fonts.length}'),
                font: font,
                onChanged: (f) => cubit.updateFonts([...fonts]..[i] = f),
                onRemove: () => cubit.updateFonts([...fonts]..removeAt(i)),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Añadir fuente'),
              onPressed: () async {
                if (await _pickSystemFont(context) case final family?) {
                  cubit.updateFonts([
                    ...fonts,
                    EmbeddedFont(family: family, headingLevels: const [1]),
                  ]);
                }
              },
            ),
          ],
        ),
        FormSection(
          title: 'CSS propio',
          icon: Icons.code,
          children: [
            AppTextField(
              key: ValueKey(context.select((EpubTemplaterCubit c) => c.state.revision)),
              label: 'Reglas',
              value: context.select((EpubTemplaterCubit c) => c.state.project.customCss),
              hint: '.carta {\n  font-style: italic;\n}',
              helper: 'Se añaden al final de style.css, después de las fuentes.',
              minLines: 6,
              maxLines: 16,
              onChanged: cubit.setCustomCss,
            ),
          ],
        ),
      ],
    );
  }
}

class const _FontCard({super.key, required final EmbeddedFont font, required final ValueChanged<EmbeddedFont> onChanged, required final VoidCallback onRemove}) extends StatelessWidget {
  // La familia se lee del primer archivo, o de su nombre si no se puede analizar.
  void _useFiles(List<String> paths) => onChanged(font.copyWith(family: readFontFace(paths.first)?.family ?? p.basenameWithoutExtension(paths.first), files: paths));

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.medium + AppPadding.small, AppPadding.small, AppPadding.small, AppPadding.medium + AppPadding.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Row(
              children: [
                Expanded(child: Text(font.family.isEmpty ? 'Fuente sin elegir' : font.family, style: textTheme.titleSmall)),
                IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
              ],
            ),
            Text('Título de ejemplo — Capítulo 1', style: TextStyle(fontFamily: font.family, fontSize: 22)),
            FieldGrid(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.font_download_outlined),
                  label: const Text('Fuente del sistema…'),
                  onPressed: () async {
                    if (await _pickSystemFont(context) case final family?) onChanged(font.copyWith(family: family, files: const []));
                  },
                ),
                FileDropButton(
                  icon: Icons.file_open_outlined,
                  label: 'Archivos…',
                  dropLabel: 'Suelta aquí la fuente',
                  extensions: fontExtensions,
                  onPick: () async {
                    final paths = (await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: fontExtensions,
                      dialogTitle: 'Seleccionar archivos de la fuente',
                      windowsOptions: const WindowsOptions(lockParentWindow: true),
                      linuxOptions: const LinuxOptions(lockParentWindow: true),
                    )).map((f) => f.path).whereType<String>().toList();
                    if (paths.isNotEmpty) _useFiles(paths);
                  },
                  onFiles: _useFiles,
                ),
                OutlinedDropdown<GenericFamily>(
                  label: 'Respaldo',
                  value: font.fallback,
                  onChanged: (v) => onChanged(font.copyWith(fallback: v ?? GenericFamily.serif)),
                  items: [for (final g in GenericFamily.values) DropdownMenuItem(value: g, child: Text(g.css))],
                ),
              ],
            ),
            if (font.files.isNotEmpty) Text(font.files.map(p.basename).join(' · '), style: textTheme.bodySmall),
            FieldGroup(
              label: 'Niveles de título',
              child: SelectionPillGroup(
                options: [for (var level = 1; level <= 9; level++) level],
                selected: font.headingLevels.contains,
                label: (level) => 'h$level',
                onTap: (level) => onChanged(font.copyWith(headingLevels: font.headingLevels.toggled(level))),
              ),
            ),
            SelectableText.rich(
              TextSpan(
                style: textTheme.bodySmall,
                children: [
                  const TextSpan(text: 'Clase: '),
                  TextSpan(
                    text: '<p class="${font.cssClass}">',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SystemFontPicker({required final Future<List<FontFace>> fonts}) extends StatefulWidget {
  @override
  State<_SystemFontPicker> createState() => _SystemFontPickerState();
}

class _SystemFontPickerState extends State<_SystemFontPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fuentes del sistema'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: FutureBuilder(
          future: widget.fonts,
          builder: (context, snapshot) {
            final faces = snapshot.data;
            if (faces == null) return const Center(child: CircularProgressIndicator());
            final families = <String, List<FontFace>>{};
            for (final f in faces) {
              families.putIfAbsent(f.family, () => []).add(f);
            }
            final visible = families.entries.where((e) => e.key.toLowerCase().contains(_query.toLowerCase())).toList();
            return Column(
              spacing: AppSpacing.medium,
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(hintText: 'Buscar', prefixIcon: Icon(Icons.search, size: 20)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final MapEntry(key: family, value: variants) = visible[i];
                      final restricted = variants.any((v) => !v.embeddable);
                      return ListTile(
                        dense: true,
                        title: Text(family, style: TextStyle(fontFamily: family, fontSize: 18)),
                        subtitle: Text('${variants.map((v) => v.style).toSet().join(', ')}${restricted ? ' · licencia sin permiso de incrustación' : ''}'),
                        trailing: restricted ? const Icon(Icons.lock_outline, size: 18) : null,
                        onTap: () => Navigator.pop(context, family),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}
