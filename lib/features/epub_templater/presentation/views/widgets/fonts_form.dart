import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/widgets/selection_pill.dart';
import '/common/widgets/file_drop_button.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/outlined_dropdown.dart';
import '../../../data/system_fonts.dart';
import '../../../domain/embedded_font.dart';
import '../../cubit/epub_templater_cubit.dart';

class FontsForm extends StatelessWidget {
  const FontsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final fonts = context.select((EpubTemplaterCubit c) => c.state.project.fonts);
    void replace(int i, EmbeddedFont font) => cubit.updateFonts([...fonts]..[i] = font);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        for (final (i, font) in fonts.indexed)
          _FontCard(
            key: ValueKey('$i-${fonts.length}'),
            font: font,
            onChanged: (f) => replace(i, f),
            onRemove: () => cubit.updateFonts([...fonts]..removeAt(i)),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Añadir fuente'),
          onPressed: () async {
            final family = await showDialog<String>(
              context: context,
              builder: (_) => _SystemFontPicker(fonts: cubit.systemFonts()),
            );
            if (family != null) {
              cubit.updateFonts([
                ...fonts,
                EmbeddedFont(family: family, headingLevels: const [1]),
              ]);
            }
          },
        ),
      ],
    );
  }
}

class _FontCard extends StatelessWidget {
  const _FontCard({super.key, required this.font, required this.onChanged, required this.onRemove});

  final EmbeddedFont font;
  final ValueChanged<EmbeddedFont> onChanged;
  final VoidCallback onRemove;

  // La familia se lee del primer archivo, o de su nombre si no se puede analizar.
  void _useFiles(List<String> paths) {
    final family = readFontFace(paths.first)?.family ?? p.basenameWithoutExtension(paths.first);
    onChanged(font.copyWith(family: family, files: paths));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    return FormSection(
      title: font.family.isEmpty ? 'Fuente' : font.family,
      trailing: IconButton(tooltip: 'Quitar', icon: const Icon(Icons.delete_outline), onPressed: onRemove),
      children: [
        Text('Título de ejemplo — Capítulo 1', style: TextStyle(fontFamily: font.family, fontSize: 22)),
        ResponsiveRow(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.font_download_outlined),
              label: const Text('Fuente del sistema…'),
              onPressed: () async {
                final family = await showDialog<String>(
                  context: context,
                  builder: (_) => _SystemFontPicker(fonts: cubit.systemFonts()),
                );
                if (family != null) onChanged(font.copyWith(family: family, files: const []));
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
        if (font.files.isNotEmpty) Text(font.files.map(p.basename).join(' · '), style: Theme.of(context).textTheme.bodySmall),
        Text('Niveles de título', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.small,
          children: [
            for (var level = 1; level <= 9; level++)
              SelectionPill(
                selected: font.headingLevels.contains(level),
                onTap: () => onChanged(font.copyWith(headingLevels: font.headingLevels.contains(level) ? ([...font.headingLevels]..remove(level)) : [...font.headingLevels, level])),
                child: Text('h$level'),
              ),
          ],
        ),
        SelectableText.rich(
          TextSpan(
            style: Theme.of(context).textTheme.bodySmall,
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
    );
  }
}

class _SystemFontPicker extends StatefulWidget {
  const _SystemFontPicker({required this.fonts});

  final Future<List<FontFace>> fonts;

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
