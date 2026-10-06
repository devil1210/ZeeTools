import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/outlined_dropdown.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/toggle_field.dart';
import '/features/epub_templater/domain/content_warning.dart';
import '../../../domain/migration_kind.dart';
import '../../../domain/migration_project.dart';
import '../../cubit/epub_migrator_cubit.dart';
import 'file_preview.dart';

class SectionsTab extends StatelessWidget {
  const SectionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = context.select((EpubMigratorCubit c) => c.state.project!.docs);
    final revision = context.select((EpubMigratorCubit c) => c.state.revision);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      itemCount: docs.length + 1,
      itemBuilder: (context, i) => i == 0 ? const _BookOptions() : _DocCard(key: ValueKey('$revision-${docs[i - 1].path}'), index: i - 1, doc: docs[i - 1]),
    );
  }
}

class _BookOptions extends StatelessWidget {
  const _BookOptions();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubMigratorCubit>();
    final project = context.select((EpubMigratorCubit c) => c.state.project!);
    final hasNotice = project.docs.any((d) => d.kind == MigrationKind.notice);
    final hasLogos = project.docs.any((d) => d.kind == MigrationKind.colophon);
    return FormSection(
      title: 'Páginas del template',
      children: [
        ResponsiveRow(
          children: [
            if (hasNotice)
              const ToggleField(label: 'El libro tiene advertencia', value: true, onChanged: null, helper: 'Su texto se cambia por el estándar del tipo elegido.')
            else
              ToggleField(label: 'Añadir advertencia', value: project.addNotice, onChanged: cubit.setAddNotice, helper: 'advertencia.xhtml tras la cubierta.'),
            if (hasNotice || project.addNotice)
              OutlinedDropdown<ContentWarning>(
                label: 'Tipo de advertencia',
                value: project.warning,
                onChanged: (v) => cubit.setWarning(v!),
                items: [for (final w in ContentWarning.values) DropdownMenuItem(value: w, child: Text(w.label))],
              ),
            ToggleField(
              label: hasLogos ? 'El libro tiene página de logos' : 'Añadir logos.xhtml',
              value: hasLogos || project.addLogos,
              onChanged: hasLogos ? null : cubit.setAddLogos,
              helper: hasLogos ? null : 'Con el logo de ZeePubs, tras la página de título.',
            ),
          ],
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({super.key, required this.index, required this.doc});

  final int index;
  final MigrationDoc doc;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubMigratorCubit>();
    final theme = Theme.of(context);
    final issues = context.select((EpubMigratorCubit c) => c.state.issues.where((i) => i.path == doc.path && i.level != MigrationIssueLevel.info).toList());
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      color: doc.continuation ? theme.colorScheme.surfaceContainerLow : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.medium + AppPadding.small, AppPadding.small, AppPadding.small, AppPadding.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium,
          children: [
            Row(
              spacing: AppSpacing.medium,
              children: [
                Text('${index + 1}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline)),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: p.posix.basename(doc.path), style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (!doc.continuation) TextSpan(text: '  ·  ${doc.matter.label}'),
                        if (doc.oldType.isNotEmpty) TextSpan(text: '  ·  era ${doc.oldType}'),
                        if (doc.headingText.isNotEmpty) TextSpan(text: '  ·  «${doc.headingText}»'),
                        TextSpan(text: '  ·  ${doc.paragraphs} párrafos, ${doc.images} imágenes'),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: doc.continuation ? 'Separar de la sección anterior' : 'Unir a la sección anterior',
                  isSelected: doc.continuation,
                  icon: const Icon(Icons.link_off),
                  selectedIcon: const Icon(Icons.link),
                  onPressed: index == 0 || doc.broken ? null : () => cubit.updateDoc(index, (d) => d.copyWith(continuation: !d.continuation)),
                ),
                IconButton(
                  tooltip: doc.inToc ? 'Quitar del índice' : 'Incluir en el índice',
                  isSelected: doc.inToc,
                  icon: const Icon(Icons.playlist_remove),
                  selectedIcon: const Icon(Icons.playlist_add_check),
                  onPressed: doc.continuation ? null : () => cubit.updateDoc(index, (d) => d.copyWith(inToc: !d.inToc)),
                ),
                IconButton(tooltip: 'Ver el documento original', icon: const Icon(Icons.visibility_outlined), onPressed: () => showFilePreview(context, cubit.archive!, doc.path)),
              ],
            ),
            if (doc.continuation)
              Text('Se une a «${doc.label}» (${doc.fileName}.xhtml) con un salto de página.', style: theme.textTheme.bodySmall)
            else
              ResponsiveRow(
                flex: const [2, 2, 3],
                children: [
                  OutlinedDropdown<MigrationKind>(
                    label: 'Tipo',
                    value: doc.kind,
                    onChanged: (v) => cubit.changeKind(index, v!),
                    items: [for (final k in MigrationKind.values) DropdownMenuItem(value: k, child: Text(k.title))],
                  ),
                  AppTextField(label: 'Archivo', value: doc.fileName, helper: '.xhtml', onChanged: (v) => cubit.updateDoc(index, (d) => d.copyWith(fileName: v.trim()))),
                  AppTextField(label: 'Entrada del índice', value: doc.label, onChanged: (v) => cubit.updateDoc(index, (d) => d.copyWith(label: v))),
                ],
              ),
            for (final issue in issues)
              Row(
                spacing: AppSpacing.small,
                children: [
                  Icon(issue.level == MigrationIssueLevel.error ? Icons.error_outline : Icons.warning_amber_rounded, size: 16, color: issue.level == MigrationIssueLevel.error ? theme.colorScheme.error : theme.colorScheme.tertiary),
                  Expanded(child: Text(issue.message, style: theme.textTheme.bodySmall)),
                ],
              ),
            for (final note in doc.notes)
              Row(
                spacing: AppSpacing.small,
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
                  Expanded(child: Text(note, style: theme.textTheme.bodySmall)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
