import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/tag_pill.dart';
import '/common/widgets/selection_pill.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/outlined_dropdown.dart';
import '/common/widgets/editable_list.dart';
import '/common/utils/input_formatters.dart';
import '../../../data/epub_template_builder.dart';
import '../../../domain/book_metadata.dart';
import '../../../domain/marc_relator.dart';
import '../../../domain/subjects.dart';
import '../../cubit/epub_templater_cubit.dart';
import 'form_fields.dart';

class MetadataForm extends StatelessWidget {
  const MetadataForm({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final m = context.select((EpubTemplaterCubit c) => c.state.project.metadata);
    void update(BookMetadata Function(BookMetadata m) f) => cubit.updateMetadata(f);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        FormSection(
          title: 'Título y serie',
          children: [
            ResponsiveRow(
              widths: const [languageColumnWidth, null],
              children: [
                LanguageField(
                  label: 'Idioma',
                  value: m.titleLang.isEmpty ? m.language : m.titleLang,
                  onChanged: (v) => update((m) => m.copyWith(titleLang: v.trim())),
                ),
                AppTextField(
                  label: 'Título principal',
                  value: m.title,
                  hint: 'Nombre de la novela - Volumen 01 [SIGLAS]',
                  error: m.title.trim().isEmpty ? 'Obligatorio' : null,
                  onChanged: (v) => update((m) => m.copyWith(title: v)),
                ),
              ],
            ),
            _TitleSortField(
              value: m.titleSort,
              onChanged: (v) => update((m) => m.copyWith(titleSort: v)),
            ),
            _LocalizedTexts(
              items: m.altTitles,
              taken: m.titleLang.isEmpty ? m.language : m.titleLang,
              textLabel: 'Título',
              addLabel: 'Añadir título en otro idioma',
              onChanged: (v) => update((m) => m.copyWith(altTitles: v)),
            ),
            ResponsiveRow(
              widths: const [languageColumnWidth, null, numberColumnWidth],
              children: [
                LanguageField(
                  label: 'Idioma',
                  value: m.seriesLang.isEmpty ? m.language : m.seriesLang,
                  enabled: m.hasSeries,
                  onChanged: (v) => update((m) => m.copyWith(seriesLang: v.trim())),
                ),
                AppTextField(
                  label: 'Serie',
                  value: m.series,
                  onChanged: (v) => update((m) => m.copyWith(series: v)),
                ),
                AppTextField(
                  label: 'Volumen',
                  value: m.seriesIndex,
                  enabled: m.hasSeries,
                  inputFormatters: [decimalNumberFormatter],
                  error: switch (m.seriesIndex.trim()) {
                    _ when !m.hasSeries => null,
                    '' => 'Obligatorio',
                    final index when double.tryParse(index) == null => 'No es un número',
                    _ => null,
                  },
                  onChanged: (v) => update((m) => m.copyWith(seriesIndex: v)),
                ),
              ],
            ),
            if (m.hasSeries)
              _LocalizedTexts(
                items: m.altSeries,
                taken: m.seriesLang.isEmpty ? m.language : m.seriesLang,
                textLabel: 'Serie',
                addLabel: 'Añadir serie en otro idioma',
                onChanged: (v) => update((m) => m.copyWith(altSeries: v)),
              ),
          ],
        ),
        FormSection(
          title: 'Personas',
          children: [
            EditableList<Actor>(
              items: m.actors,
              addLabel: 'Añadir persona',
              createItem: () => const Actor(roles: [MarcRelator.ctb]),
              onChanged: (v) => update((m) => m.copyWith(actors: v)),
              itemBuilder: (context, actor, onChanged, controls) => _ActorEditor(actor: actor, onChanged: onChanged, controls: controls),
            ),
          ],
        ),
        FormSection(
          title: 'Publicación',
          children: [
            ResponsiveRow(
              children: [
                LanguageField(
                  label: 'Idioma del libro',
                  value: m.language,
                  onChanged: (v) => update((m) => m.copyWith(language: v.trim())),
                ),
                _BookTypeField(
                  value: m.bookType,
                  onChanged: (v) => update((m) => m.copyWith(bookType: v)),
                ),
                _DateField(
                  value: m.date,
                  onChanged: (v) => update((m) => m.copyWith(date: v)),
                ),
              ],
            ),
            Text('Editorial o grupo', style: Theme.of(context).textTheme.labelLarge),
            EditableList<String>(
              items: m.publishers,
              addLabel: 'Añadir editorial',
              createItem: () => '',
              onChanged: (v) => update((m) => m.copyWith(publishers: v)),
              itemBuilder: (context, publisher, onChanged, controls) => EditableRow(
                controls: controls,
                child: AppTextField(label: 'Nombre', value: publisher, onChanged: onChanged),
              ),
            ),
            Text('Enlaces en la página de título', style: Theme.of(context).textTheme.labelLarge),
            EditableList<WebLink>(
              items: m.links,
              addLabel: 'Añadir enlace',
              createItem: () => const WebLink(),
              onChanged: (v) => update((m) => m.copyWith(links: v)),
              itemBuilder: (context, link, onChanged, controls) => EditableRow(
                controls: controls,
                child: ResponsiveRow(
                  flex: const [1, 2],
                  children: [
                    AppTextField(
                      label: 'Etiqueta',
                      value: link.label,
                      hint: 'Página Web',
                      onChanged: (v) => onChanged(link.copyWith(label: v)),
                    ),
                    AppTextField(
                      label: 'URL',
                      value: link.url,
                      onChanged: (v) => onChanged(link.copyWith(url: v.trim())),
                    ),
                  ],
                ),
              ),
            ),
            AppTextField(
              label: 'Sinopsis',
              value: m.description,
              maxLines: 12,
              onChanged: (v) => update((m) => m.copyWith(description: v)),
            ),
          ],
        ),
        FormSection(
          title: 'Clasificación',
          children: [
            Text('Demografía', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                for (final d in Demographic.values)
                  SelectionPill(
                    tooltip: 'Añade también «${d.ageGroup}»',
                    selected: m.demographic == d,
                    onTap: () => update((m) => m.copyWith(demographic: m.demographic == d ? null : d)),
                    child: Text(d.label),
                  ),
              ],
            ),
            Text('Géneros', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                for (final genre in literaryGenres)
                  SelectionPill(
                    selected: m.genres.contains(genre),
                    onTap: () => update((m) => m.copyWith(genres: m.genres.contains(genre) ? ([...m.genres]..remove(genre)) : [...m.genres, genre])),
                    child: Text(genre),
                  ),
              ],
            ),
            OutlinedDropdown<int?>(
              label: 'Calificación de calibre',
              value: m.rating,
              onChanged: (v) => update((m) => m.copyWith(rating: v)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin calificar')),
                for (var r = 1; r <= 10; r++) DropdownMenuItem(value: r, child: Text('${'★' * (r ~/ 2)}${r.isOdd ? '½' : ''}')),
              ],
            ),
          ],
        ),
        FormSection(
          title: 'Identificadores',
          children: [
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Identificador único'),
                    child: SelectableText('urn:uuid:${m.identifier}'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: 'urn:uuid:${m.identifier}')),
                ),
                IconButton(
                  tooltip: 'Generar otro',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: cubit.regenerateIdentifier,
                ),
              ],
            ),
            ResponsiveRow(
              children: [
                AppTextField(
                  label: 'ISBN-13',
                  value: m.isbn13,
                  error: m.isbn13.trim().isNotEmpty && !isValidIsbn13(m.isbn13) ? 'ISBN-13 no válido' : null,
                  onChanged: (v) => update((m) => m.copyWith(isbn13: v)),
                ),
                AppTextField(
                  label: 'ISBN-10',
                  value: m.isbn10,
                  error: m.isbn10.trim().isNotEmpty && !isValidIsbn10(m.isbn10) ? 'ISBN-10 no válido' : null,
                  onChanged: (v) => update((m) => m.copyWith(isbn10: v)),
                ),
                AppTextField(
                  label: 'ASIN de Amazon',
                  value: m.asin,
                  onChanged: (v) => update((m) => m.copyWith(asin: v.trim())),
                ),
              ],
            ),
            AppTextField(
              label: 'Enlace de la publicación',
              value: m.sourceUrl,
              hint: 'https://grupotraductor.com/nombre-novela',
              onChanged: (v) => update((m) => m.copyWith(sourceUrl: v.trim())),
            ),
          ],
        ),
      ],
    );
  }
}

// [taken] es el idioma de la propiedad principal; ningún equivalente puede repetirlo.
class _LocalizedTexts extends StatelessWidget {
  const _LocalizedTexts({required this.items, required this.taken, required this.textLabel, required this.addLabel, required this.onChanged});

  final List<LocalizedText> items;
  final String taken;
  final String textLabel;
  final String addLabel;
  final ValueChanged<List<LocalizedText>> onChanged;

  @override
  Widget build(BuildContext context) {
    String key(String lang) => lang.trim().toLowerCase();
    final counts = <String, int>{key(taken): 1};
    for (final t in items) {
      counts.update(key(t.lang), (n) => n + 1, ifAbsent: () => 1);
    }
    return EditableList<LocalizedText>(
      items: items,
      addLabel: addLabel,
      reorderable: false,
      createItem: () => const LocalizedText(),
      onChanged: onChanged,
      itemBuilder: (context, t, update, controls) => EditableRow(
        controls: controls,
        child: ResponsiveRow(
          widths: const [languageColumnWidth, null],
          children: [
            LanguageField(
              label: 'Idioma',
              value: t.lang,
              error: key(t.lang).isNotEmpty && counts[key(t.lang)]! > 1 ? 'Idioma repetido' : null,
              onChanged: (v) => update(t.copyWith(lang: v.trim())),
            ),
            AppTextField(
              label: textLabel,
              value: t.text,
              onChanged: (v) => update(t.copyWith(text: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleSortField extends StatefulWidget {
  const _TitleSortField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TitleSortField> createState() => _TitleSortFieldState();
}

// Se usa poco: queda tras un botón mientras esté vacío.
class _TitleSortFieldState extends State<_TitleSortField> {
  late bool _open = widget.value.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.sort_by_alpha, size: 18),
          label: const Text('Título para ordenar'),
          onPressed: () => setState(() => _open = true),
        ),
      );
    }
    return AppTextField(
      label: 'Título para ordenar',
      value: widget.value,
      onChanged: widget.onChanged,
      suffix: IconButton(
        tooltip: 'Quitar',
        icon: const Icon(Icons.close, size: 18),
        onPressed: () {
          widget.onChanged('');
          setState(() => _open = false);
        },
      ),
    );
  }
}

class _ActorEditor extends StatefulWidget {
  const _ActorEditor({required this.actor, required this.onChanged, required this.controls});

  final Actor actor;
  final ValueChanged<Actor> onChanged;
  final Widget controls;

  @override
  State<_ActorEditor> createState() => _ActorEditorState();
}

class _ActorEditorState extends State<_ActorEditor> {
  late final _fileAs = TextEditingController(text: widget.actor.fileAs);

  @override
  void dispose() {
    _fileAs.dispose();
    super.dispose();
  }

  // El orden se deduce del nombre mientras nadie lo haya editado a mano.
  void _onNameChanged(String name) {
    final actor = widget.actor;
    final follows = actor.fileAs.isEmpty || actor.fileAs == fileAsFor(actor.name);
    final fileAs = follows ? fileAsFor(name) : actor.fileAs;
    if (fileAs != _fileAs.text) _fileAs.text = fileAs;
    widget.onChanged(actor.copyWith(name: name, fileAs: fileAs));
  }

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.medium + AppPadding.small, AppPadding.medium + AppPadding.small, AppPadding.small, AppPadding.medium + AppPadding.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.medium,
              children: [
                Expanded(
                  child: ResponsiveRow(
                    children: [
                      AppTextField(label: 'Nombre', value: actor.name, onChanged: _onNameChanged),
                      if (actor.name.trim().isNotEmpty)
                        TextField(
                          controller: _fileAs,
                          onChanged: (v) => widget.onChanged(actor.copyWith(fileAs: v)),
                          decoration: const InputDecoration(labelText: 'Nombre para ordenar'),
                        ),
                    ],
                  ),
                ),
                widget.controls,
              ],
            ),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(actor.isCreator ? 'Creador:' : 'Colaborador:', style: Theme.of(context).textTheme.labelLarge),
                for (final role in actor.roles)
                  TagPill(
                    label: role.label,
                    tooltip: 'marc:relators ${role.name}',
                    onRemove: actor.roles.length == 1 ? null : () => widget.onChanged(actor.copyWith(roles: [...actor.roles]..remove(role))),
                  ),
                PopupMenuButton<MarcRelator>(
                  tooltip: 'Añadir función',
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onSelected: (role) => widget.onChanged(actor.copyWith(roles: [...actor.roles, role])),
                  itemBuilder: (_) => [
                    for (final role in MarcRelator.values)
                      if (!actor.roles.contains(role)) PopupMenuItem(value: role, child: Text('${role.label} (${role.name})')),
                  ],
                ),
              ],
            ),
            _LocalizedTexts(
              items: actor.altNames,
              taken: '',
              textLabel: 'Nombre',
              addLabel: 'Añadir nombre en otro idioma',
              onChanged: (v) => widget.onChanged(actor.copyWith(altNames: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTypeField extends StatelessWidget {
  const _BookTypeField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value),
      optionsBuilder: (v) => bookTypes.where((t) => t.toLowerCase().contains(v.text.toLowerCase())),
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: const InputDecoration(labelText: 'Tipo'),
      ),
    );
  }
}

// Solo se elige desde el calendario, que se despliega bajo el campo.
class _DateField extends StatefulWidget {
  const _DateField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.value);
    return MenuAnchor(
      controller: _menu,
      menuChildren: [
        SizedBox(
          width: 320,
          height: 340,
          // El menú ya usa el controlador de desplazamiento primario.
          child: PrimaryScrollController.none(
            child: CalendarDatePicker(
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              onDateChanged: (picked) {
                widget.onChanged(picked.toIso8601String().substring(0, 10));
                _menu.close();
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.small),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: InputDecorator(
          isEmpty: date == null,
          decoration: InputDecoration(
            labelText: 'Fecha de publicación',
            suffixIcon: date == null ? const Icon(Icons.calendar_today, size: 18) : IconButton(tooltip: 'Quitar fecha', icon: const Icon(Icons.close, size: 18), onPressed: () => widget.onChanged('')),
          ),
          child: Text(date == null ? '' : MaterialLocalizations.of(context).formatMediumDate(date)),
        ),
      ),
    );
  }
}
