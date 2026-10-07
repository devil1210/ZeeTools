import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/toggle_field.dart';
import '/common/widgets/confirm_dialog.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/outlined_dropdown.dart';
import '../../../data/epub_template_builder.dart';
import '../../../domain/section_kind.dart';
import '../../../domain/template_section.dart';
import '../../cubit/epub_templater_cubit.dart';

class SectionEditor extends StatelessWidget {
  const SectionEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final section = context.select((EpubTemplaterCubit c) => c.state.selected);
    if (section == null) return const Center(child: Text('Selecciona o añade una sección.'));
    final revision = context.select((EpubTemplaterCubit c) => c.state.revision);
    return _SectionForm(key: ValueKey('${section.key}-${section.kind.name}-$revision'), section: section);
  }
}

class _SectionForm extends StatelessWidget {
  const _SectionForm({super.key, required this.section});

  final TemplateSection section;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final s = section;
    void update(TemplateSection Function(TemplateSection s) f) => cubit.updateSection(s.key, f);
    final isTitlePage = s.kind.layout == SectionLayout.titlePage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        FormSection(
          title: 'Sección',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: 'Duplicar', icon: const Icon(Icons.copy_all_outlined), onPressed: () => cubit.duplicateSection(s.key)),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Eliminar sección',
                    message: 'Se perderán «${s.effectiveTocLabel}», su configuración y las imágenes asignadas.',
                    confirmLabel: 'Eliminar',
                  );
                  if (confirmed) cubit.removeSection(s.key);
                },
              ),
            ],
          ),
          children: [
            ResponsiveRow(
              children: [
                DropdownButtonFormField<SectionKind>(
                  initialValue: s.kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  onChanged: (kind) {
                    if (kind != null && kind != s.kind) cubit.changeKind(s.key, kind);
                  },
                  items: [
                    for (final kind in SectionKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label),
                      ),
                  ],
                ),
                AppTextField(
                  label: 'Archivo',
                  value: s.fileName,
                  suffix: const Padding(padding: EdgeInsets.all(AppPadding.medium), child: Text('.xhtml')),
                  error: sanitizeFileName(s.fileName) != s.fileName.trim() ? 'Solo letras, números, «-» y «_»' : null,
                  onChanged: (v) => update((s) => s.copyWith(fileName: v)),
                ),
              ],
            ),
          ],
        ),
        FormSection(
          title: isTitlePage ? 'Título de la obra' : 'Encabezado',
          children: [
            ResponsiveRow(
              children: [
                AppTextField(
                  label: isTitlePage ? 'Título de la obra' : 'Título visible',
                  value: s.title,
                  hint: isTitlePage ? 'Vacío: el título del libro en su idioma' : null,
                  onChanged: (v) => update((s) => s.copyWith(title: v)),
                ),
                AppTextField(
                  label: isTitlePage ? 'Subtítulo de la obra' : 'Subtítulo',
                  value: s.subtitle,
                  helper: 'Se muestra en una segunda línea más pequeña.',
                  onChanged: (v) => update((s) => s.copyWith(subtitle: v)),
                ),
              ],
            ),
            ResponsiveRow(
              children: [
                ToggleField(
                  label: 'Ocultar encabezado',
                  helper: s.inToc ? 'Sigue presente para el índice y los lectores de pantalla.' : 'Sigue presente para los lectores de pantalla.',
                  value: s.hideHeading,
                  onChanged: (v) => update((s) => s.copyWith(hideHeading: v)),
                ),
                if (s.kind.layout == SectionLayout.text)
                  DropdownButtonFormField<HeadingStyle>(
                    initialValue: s.headingStyle,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Imagen del encabezado',
                      helperText: switch (s.headingStyle) {
                        HeadingStyle.text => null,
                        HeadingStyle.imageBefore || HeadingStyle.imageAfter => 'Adorno pequeño (clase logo) junto al título.',
                        HeadingStyle.imageTitle => 'La imagen sustituye al título visible; el encabezado queda oculto para el índice.',
                        HeadingStyle.separatorPage => 'Se generan dos archivos: el índice apunta a la imagen a página completa y el título visible abre el siguiente.',
                      },
                      helperMaxLines: 3,
                    ),
                    onChanged: (v) => update((s) => s.copyWith(headingStyle: v ?? HeadingStyle.text)),
                    items: [for (final style in HeadingStyle.values) DropdownMenuItem(value: style, child: Text(style.label))],
                  ),
              ],
            ),
          ],
        ),
        if (s.kind.layout == SectionLayout.notice)
          FormSection(
            title: 'Advertencia',
            children: [
              OutlinedDropdown<ContentWarning>(
                label: 'Tipo',
                value: s.warning,
                helper: s.warning.text,
                onChanged: (v) => update((s) => s.copyWith(warning: v ?? ContentWarning.explicit)),
                items: [for (final w in ContentWarning.values) DropdownMenuItem(value: w, child: Text(w.label))],
              ),
            ],
          ),
        FormSection(
          title: 'Índice',
          children: [
            ResponsiveRow(
              flex: isTitlePage ? const [2, 1] : const [2, 4, 1],
              children: [
                ToggleField(
                  label: 'Incluir en el índice',
                  value: s.inToc,
                  helper: isTitlePage ? 'Como «${s.effectiveTocLabel}».' : null,
                  onChanged: (v) => update((s) => s.copyWith(inToc: v)),
                ),
                if (!isTitlePage)
                  AppTextField(
                    label: 'Nombre en el índice',
                    value: s.tocLabel,
                    hint: s.copyWith(tocLabel: '').effectiveTocLabel,
                    helper: 'Vacío: título y subtítulo. También se usa como título del documento.',
                    onChanged: (v) => update((s) => s.copyWith(tocLabel: v)),
                  ),
                DropdownButtonFormField<int>(
                  initialValue: s.level.clamp(1, 6),
                  decoration: const InputDecoration(labelText: 'Nivel', helperText: 'h1–h6'),
                  onChanged: (v) => update((s) => s.copyWith(level: v ?? 1)),
                  items: [for (var l = 1; l <= 6; l++) DropdownMenuItem(value: l, child: Text('$l'))],
                ),
              ],
            ),
          ],
        ),
        FormSection(
          title: 'Semántica y accesibilidad',
          children: [
            SegmentedButton<BookMatter>(
              showSelectedIcon: false,
              segments: [for (final m in BookMatter.values) ButtonSegment(value: m, label: Text(m.label), tooltip: m.epubType)],
              selected: {s.matter},
              onSelectionChanged: (v) => update((s) => s.copyWith(matter: v.first)),
            ),
            OutlinedDropdown<String>(
              label: 'epub:type',
              value: epubTypeRoles.containsKey(s.epubType) ? s.epubType : '',
              helper: s.role.isEmpty ? 'Sin rol ARIA equivalente' : 'Rol ARIA: ${s.role}',
              onChanged: (v) => update((s) => s.copyWith(epubType: v ?? '')),
              items: [
                const DropdownMenuItem(value: '', child: Text('Ninguno')),
                for (final type in epubTypeRoles.keys) DropdownMenuItem(value: type, child: Text(type)),
              ],
            ),
            AppTextField(
              label: 'Etiqueta ARIA',
              value: s.ariaLabel,
              helper: 'Vacío: la sección se etiqueta con su encabezado (aria-labelledby).',
              onChanged: (v) => update((s) => s.copyWith(ariaLabel: v)),
            ),
          ],
        ),
      ],
    );
  }
}
