import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/form_section.dart';
import '../../cubit/epub_migrator_cubit.dart';

class StylesTab extends StatelessWidget {
  const StylesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubMigratorCubit>();
    final project = context.select((EpubMigratorCubit c) => c.state.project!);
    final theme = Theme.of(context);
    final renames = project.classRenames.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        FormSection(
          title: 'Clases del template anterior',
          children: [
            if (renames.isEmpty) const Text('El libro no usa clases que cambien de nombre.'),
            for (final MapEntry(key: old, value: classes) in renames)
              Row(
                spacing: AppSpacing.medium,
                children: [
                  SizedBox(width: 160, child: SelectableText('.$old', style: const TextStyle(fontFamily: 'Consolas'))),
                  const Icon(Icons.arrow_forward, size: 18),
                  Expanded(
                    child: AppTextField(
                      key: ValueKey(old),
                      label: 'Clases nuevas',
                      value: classes.join(' '),
                      hint: 'Sin clase',
                      onChanged: (v) => cubit.setRenames(old, v.split(RegExp(r'\s+')).where((c) => c.isNotEmpty).toList()),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (project.unknownClasses.isNotEmpty)
          FormSection(
            title: 'Clases sin equivalente ni regla',
            children: [
              Text('El template no las define y el libro no tiene regla para ellas. Dales un equivalente o escribe su regla en el CSS propio.', style: theme.textTheme.bodySmall),
              Wrap(
                spacing: AppSpacing.medium,
                runSpacing: AppSpacing.small,
                children: [
                  for (final c in project.unknownClasses)
                    ActionChip(
                      avatar: Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.tertiary),
                      label: Text('.$c'),
                      tooltip: project.classRenames.containsKey(c) ? null : 'Darle un equivalente',
                      onPressed: project.classRenames.containsKey(c) ? null : () => cubit.setRenames(c, const []),
                    ),
                ],
              ),
            ],
          ),
        FormSection(
          title: 'CSS propio',
          children: [
            AppTextField(
              label: 'Reglas',
              value: project.customCss,
              helper: 'Lo propio del libro que se conserva al final de style.css: reglas de sus clases y fuentes incrustadas.',
              maxLines: 24,
              onChanged: cubit.setCustomCss,
            ),
          ],
        ),
      ],
    );
  }
}
