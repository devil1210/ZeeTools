import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/toggle_field.dart';
import '../../../domain/section_kind.dart';
import '../../../domain/template_section.dart';
import '../../cubit/epub_templater_cubit.dart';

typedef _Row = ({BookMatter? header, TemplateSection? section});

// Índice de secciones en el orden del spine, agrupado por división. Soltar una
// sección bajo otro separador la cambia de división.
class const SectionsPanel({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final sections = context.select((EpubTemplaterCubit c) => c.state.project.sections);
    final selectedKey = context.select((EpubTemplaterCubit c) => c.state.selectedKey);
    final rows = <_Row>[
      for (final matter in BookMatter.values) ...[
        (header: matter, section: null),
        for (final s in sections.where((s) => s.matter == matter)) (header: null, section: s),
      ],
    ];

    void onReorder(int oldIndex, int newIndex) {
      final moved = rows[oldIndex].section;
      if (moved == null) return;
      final reordered = [...rows];
      reordered.insert(newIndex, reordered.removeAt(oldIndex));
      var matter = BookMatter.front;
      var position = 0;
      for (final row in reordered) {
        if (row.header case final header?) {
          matter = header;
          position = 0;
        } else if (row.section!.key == moved.key) {
          cubit.moveSection(moved.key, matter, position);
          return;
        } else {
          position++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium, AppPadding.medium, AppPadding.medium),
          child: Row(
            children: [
              Expanded(child: Text('Secciones (${sections.length})', style: Theme.of(context).textTheme.titleSmall)),
              AddSectionButton(onSelected: cubit.addSection),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppPadding.large, 0, AppPadding.large, AppPadding.medium),
          child: ToggleField(
            label: 'Comentarios de guía',
            value: context.select((EpubTemplaterCubit c) => c.state.project.guideComments),
            onChanged: cubit.setGuideComments,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            onReorderItem: onReorder,
            itemBuilder: (context, i) => switch (rows[i]) {
              (header: final matter?, section: _) => _MatterHeader(key: ValueKey(matter), matter: matter, first: i == 0),
              (header: _, section: final s?) => _SectionTile(
                key: ValueKey(s.key),
                section: s,
                index: i,
                selected: s.key == selectedKey,
                onTap: () => cubit.select(s.key),
                onToggleToc: () => cubit.updateSection(s.key, (s) => s.copyWith(inToc: !s.inToc)),
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

class const _MatterHeader({super.key, required final BookMatter matter, required final bool first}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppPadding.large, first ? AppPadding.medium : AppPadding.large, AppPadding.large, AppPadding.small),
      child: Row(
        spacing: AppSpacing.medium,
        children: [
          Text(matter.label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

class const AddSectionButton({super.key, required final ValueChanged<SectionKind> onSelected}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SectionKind>(
      tooltip: 'Añadir sección',
      icon: const Icon(Icons.add),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final matter in BookMatter.values) ...[
          PopupMenuItem<SectionKind>(enabled: false, height: 32, child: Text(matter.label, style: Theme.of(context).textTheme.labelSmall)),
          for (final kind in SectionKind.values.where((k) => k.matter == matter))
            PopupMenuItem(
              value: kind,
              child: Text(kind.label),
            ),
        ],
      ],
    );
  }
}

class const _SectionTile({super.key, required final TemplateSection section, required final int index, required final bool selected, required final VoidCallback onTap, required final VoidCallback onToggleToc}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = section;
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -4),
      minVerticalPadding: AppPadding.small,
      selected: selected,
      onTap: onTap,
      contentPadding: EdgeInsets.only(left: AppPadding.large * s.level.clamp(1, 6), right: AppPadding.small),
      leading: const Icon(Icons.article_outlined, size: 20),
      title: Text(s.effectiveTocLabel.isEmpty ? s.kind.label : s.effectiveTocLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${s.href} · ${s.kind.label}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: s.inToc ? 'Quitar del índice' : 'Mostrar en el índice',
            icon: Icon(s.inToc ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            onPressed: onToggleToc,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(padding: EdgeInsets.all(AppPadding.medium), child: Icon(Icons.drag_handle, size: 20)),
          ),
        ],
      ),
    );
  }
}
