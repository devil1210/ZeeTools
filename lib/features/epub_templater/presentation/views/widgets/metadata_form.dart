import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/common/theme/app_dimensions.dart';
import '/common/utils/input_formatters.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/editable_list.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/outlined_dropdown.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/selection_pill.dart';
import '/common/widgets/tag_pill.dart';
import '/features/settings/data/preferences_repo.dart';
import '/features/settings/domain/date_display_format.dart';
import '/inject_dependencies.dart';
import '../../../data/epub_template_builder.dart';
import '../../../domain/book_metadata.dart';
import '../../../domain/marc_relator.dart';
import '../../../domain/metadata_field.dart';
import '../../../domain/subjects.dart';
import '../../../domain/title_languages.dart';
import 'amazon_lookup.dart';
import 'form_fields.dart';

const mixedValuesHint = 'Varios valores';
const noValueHint = 'Sin valor';

// [mixed]: campos que difieren entre los libros editados; se muestran vacíos y
// solo se aplican a todos si se les da un valor. Con [multiple], los campos que
// ningún libro tiene se señalan como vacíos en todos.
class MetadataForm extends StatelessWidget {
  const MetadataForm({super.key, required this.metadata, required this.onChanged, this.mixed = const {}, this.multiple = false, this.onRegenerateIdentifier, this.showLinks = true});

  final BookMetadata metadata;
  final ValueChanged<BookMetadata Function(BookMetadata m)> onChanged;
  final Set<MetadataField> mixed;
  final bool multiple;
  final VoidCallback? onRegenerateIdentifier;
  final bool showLinks;

  String? _status(MetadataField field) {
    if (mixed.contains(field)) return mixedValuesHint;
    if (!multiple) return null;
    return switch (field.read(metadata)) {
      null => noValueHint,
      String value when value.trim().isEmpty => noValueHint,
      List<Object?> value when value.isEmpty => noValueHint,
      _ => null,
    };
  }

  String? _hint(MetadataField field, [String? hint]) => _status(field) ?? hint;

  bool _float(MetadataField field) => _status(field) != null;

  @override
  Widget build(BuildContext context) {
    final m = metadata;
    final update = onChanged;
    final hasSeries = m.hasSeries || mixed.contains(MetadataField.series);
    final required = requiredAlternate(m.language);
    final bookOriginal = OriginalLanguage.values.where((o) => o.name == required).firstOrNull;
    final original = bookOriginal ?? originalLanguageOf(m.altTitles) ?? originalLanguageOf(m.altSeries);
    Widget label(String text, MetadataField field) => Text([text, ?_status(field)].join(' · '), style: Theme.of(context).textTheme.labelLarge);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        FormSection(
          title: 'Identificadores',
          children: [
            ResponsiveRow(
              children: [
                AppTextField(
                  label: 'ASIN de Amazon',
                  value: m.asin,
                  hint: _hint(MetadataField.asin),
                  floatLabel: _float(MetadataField.asin),
                  onChanged: (v) => update((m) => m.copyWith(asin: v.trim().toUpperCase())),
                ),
                AppTextField(
                  label: 'ISBN-13',
                  value: m.isbn13,
                  hint: _hint(MetadataField.isbn13, '978-XX-XXXX-XXX-X'),
                  floatLabel: _float(MetadataField.isbn13),
                  inputFormatters: [isbnFormatter(isbn13Groups)],
                  error: m.isbn13.trim().isNotEmpty && !isValidIsbn13(m.isbn13) ? 'ISBN-13 no válido' : null,
                  onChanged: (v) => update((m) => m.copyWith(
                    isbn13: v,
                    isbn10: switch (isbn10From13(v)) {
                      final ten? when m.isbn10.trim().isEmpty => formatIsbn(ten, isbn10Groups),
                      _ => m.isbn10,
                    },
                  )),
                ),
                AppTextField(
                  label: 'ISBN-10',
                  value: m.isbn10,
                  hint: _hint(MetadataField.isbn10, 'XX-XXXX-XXX-X'),
                  floatLabel: _float(MetadataField.isbn10),
                  inputFormatters: [isbnFormatter(isbn10Groups)],
                  error: m.isbn10.trim().isNotEmpty && !isValidIsbn10(m.isbn10) ? 'ISBN-10 no válido' : null,
                  onChanged: (v) => update((m) => m.copyWith(
                    isbn10: v,
                    isbn13: switch (isbn13From10(v)) {
                      final thirteen? when m.isbn13.trim().isEmpty => formatIsbn(thirteen, isbn13Groups),
                      _ => m.isbn13,
                    },
                  )),
                ),
              ],
            ),
            if (!multiple) AmazonLookup(asin: m.asin, metadata: m, onApply: update),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Identificador único'),
                    child: mixed.contains(MetadataField.identifier) ? const Text(mixedValuesHint) : SelectableText('urn:uuid:${m.identifier}'),
                  ),
                ),
                if (!mixed.contains(MetadataField.identifier))
                  IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => Clipboard.setData(ClipboardData(text: 'urn:uuid:${m.identifier}')),
                  ),
                if (onRegenerateIdentifier case final regenerate?)
                  IconButton(
                    tooltip: 'Generar otro',
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: regenerate,
                  ),
              ],
            ),
            AppTextField(
              label: 'Enlace de la publicación',
              value: m.sourceUrl,
              hint: _hint(MetadataField.sourceUrl, 'https://grupotraductor.com/nombre-novela'),
              floatLabel: _float(MetadataField.sourceUrl),
              onChanged: (v) => update((m) => m.copyWith(sourceUrl: v.trim())),
            ),
          ],
        ),
        FormSection(
          title: 'Título y serie',
          children: [
            AppTextField(
              label: 'Título en inglés',
              value: m.title,
              hint: _hint(MetadataField.title, 'Nombre de la novela - Volumen 01 [SIGLAS]'),
              floatLabel: _float(MetadataField.title),
              error: m.title.trim().isEmpty && !mixed.contains(MetadataField.title) ? 'Obligatorio' : null,
              onChanged: (v) => update((m) => m.copyWith(title: v, titleLang: mainTitleLanguage)),
            ),
            _TitleSortField(
              value: m.titleSort,
              hint: mixed.contains(MetadataField.titleSort) ? mixedValuesHint : null,
              onChanged: (v) => update((m) => m.copyWith(titleSort: v)),
            ),
            if (m.title.trim().isNotEmpty || mixed.contains(MetadataField.title) || original != null)
              _Alternates(
                items: m.altTitles,
                required: required,
                original: original,
                noun: 'Título',
                hint: _hint(MetadataField.altTitles),
                requiredError: !mixed.contains(MetadataField.altTitles),
                showRequired: m.title.trim().isNotEmpty || mixed.contains(MetadataField.title),
                onChanged: (v) => update((m) => m.copyWith(altTitles: v)),
              ),
            OutlinedDropdown<OriginalLanguage?>(
              label: 'Idioma en que se escribió la obra',
              value: original,
              helper: bookOriginal != null ? 'El del libro.' : 'Opcional: añade el título y la serie romanizados y en su escritura.',
              onChanged: bookOriginal != null ? null : (v) => update((m) => m.copyWith(altTitles: withOriginalLanguage(m.altTitles, v), altSeries: m.hasSeries ? withOriginalLanguage(m.altSeries, v) : m.altSeries)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Otro o sin indicar')),
                for (final o in OriginalLanguage.values) DropdownMenuItem(value: o, child: Text(o.label)),
              ],
            ),
            ResponsiveRow(
              widths: const [null, numberColumnWidth],
              children: [
                AppTextField(
                  label: 'Serie en inglés',
                  value: m.series,
                  hint: _hint(MetadataField.series),
                  floatLabel: _float(MetadataField.series),
                  onChanged: (v) => update((m) => m.copyWith(series: v, seriesLang: mainTitleLanguage, altSeries: m.hasSeries ? m.altSeries : withOriginalLanguage(m.altSeries, original))),
                ),
                AppTextField(
                  label: 'Volumen',
                  value: m.seriesIndex,
                  hint: _hint(MetadataField.seriesIndex),
                  floatLabel: _float(MetadataField.seriesIndex),
                  enabled: hasSeries,
                  inputFormatters: [decimalNumberFormatter],
                  error: switch (m.seriesIndex.trim()) {
                    _ when !hasSeries => null,
                    '' when mixed.contains(MetadataField.seriesIndex) => null,
                    '' => 'Obligatorio',
                    final index when double.tryParse(index) == null => 'No es un número',
                    _ => null,
                  },
                  onChanged: (v) => update((m) => m.copyWith(seriesIndex: v)),
                ),
              ],
            ),
            if (hasSeries)
              _Alternates(
                items: m.altSeries,
                required: required,
                original: original,
                noun: 'Serie',
                hint: _hint(MetadataField.altSeries),
                onChanged: (v) => update((m) => m.copyWith(altSeries: v)),
              ),
          ],
        ),
        FormSection(
          title: 'Personas',
          children: [
            if (mixed.contains(MetadataField.actors)) label('Las personas que añadas sustituyen a las de cada libro', MetadataField.actors),
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
                OutlinedDropdown<String?>(
                  label: 'Idioma del libro',
                  value: mixed.contains(MetadataField.language) ? null : m.language,
                  hint: _hint(MetadataField.language),
                  floatLabel: _float(MetadataField.language),
                  onChanged: (v) => update((m) => m.copyWith(language: v ?? m.language)),
                  items: [
                    for (final MapEntry(key: code, value: name) in bookLanguages.entries) DropdownMenuItem(value: code, child: Text(name)),
                    if (m.language.isNotEmpty && !bookLanguages.containsKey(m.language) && !mixed.contains(MetadataField.language)) DropdownMenuItem(value: m.language, child: Text(m.language)),
                  ],
                ),
                _BookTypeField(
                  value: m.bookType,
                  hint: _hint(MetadataField.bookType),
                  floatLabel: _float(MetadataField.bookType),
                  onChanged: (v) => update((m) => m.copyWith(bookType: v)),
                ),
                _DateField(
                  value: m.date,
                  hint: _hint(MetadataField.date),
                  floatLabel: _float(MetadataField.date),
                  onChanged: (v) => update((m) => m.copyWith(date: v)),
                ),
              ],
            ),
            label('Editorial o grupo', MetadataField.publishers),
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
            if (showLinks) ...[
              label('Enlaces en la página de título', MetadataField.links),
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
            ],
            AppTextField(
              label: 'Sinopsis',
              value: m.description,
              hint: _hint(MetadataField.description),
              floatLabel: _float(MetadataField.description),
              error: m.description.trim().isEmpty && !mixed.contains(MetadataField.description) ? 'Obligatorio' : null,
              maxLines: 12,
              onChanged: (v) => update((m) => m.copyWith(description: v)),
            ),
          ],
        ),
        FormSection(
          title: 'Clasificación',
          children: [
            label('Demografía', MetadataField.demographic),
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
            label('Géneros', MetadataField.genres),
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
            label('Edición', MetadataField.editions),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                for (final feature in editionFeatures)
                  SelectionPill(
                    selected: m.editions.contains(feature),
                    onTap: () => update((m) => m.copyWith(editions: m.editions.contains(feature) ? ([...m.editions]..remove(feature)) : [...m.editions, feature])),
                    child: Text(feature),
                  ),
              ],
            ),
            OutlinedDropdown<int?>(
              label: 'Calificación de calibre',
              value: m.rating,
              helper: mixed.contains(MetadataField.rating) ? mixedValuesHint : null,
              onChanged: (v) => update((m) => m.copyWith(rating: v)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin calificar')),
                for (var r = 1; r <= 10; r++) DropdownMenuItem(value: r, child: Text('${'★' * (r ~/ 2)}${r.isOdd ? '⯨' : ''}')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// Equivalentes de un título o serie: el del idioma del libro (obligatorio en el
// título, recomendado en la serie), el español y, si se eligió, el idioma en
// que se escribió la obra, romanizado y en su escritura.
class _Alternates extends StatelessWidget {
  const _Alternates({required this.items, required this.required, required this.original, required this.noun, required this.onChanged, this.hint, this.requiredError = false, this.showRequired = true});

  final List<LocalizedText> items;
  // Idioma del libro cuando no es el inglés del principal.
  final String? required;
  final OriginalLanguage? original;
  final String noun;
  final String? hint;
  final bool requiredError;
  final bool showRequired;
  final ValueChanged<List<LocalizedText>> onChanged;

  Widget _field(String label, String lang, {bool needed = false}) {
    final value = localizedText(items, lang);
    final empty = value.trim().isEmpty && hint == null;
    return AppTextField(
      label: '$noun $label',
      value: value,
      hint: hint,
      floatLabel: hint != null,
      error: empty && needed && requiredError ? 'Obligatorio' : null,
      helper: empty && needed && !requiredError ? 'Recomendado' : null,
      onChanged: (v) => onChanged(withLocalizedText(items, lang, v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final required = this.required;
    final original = this.original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium + AppSpacing.small,
      children: [
        if (required != null && showRequired) _field('en ${languageName(required)}', required, needed: true),
        if (required != spanishLanguage) _field('en español', spanishLanguage),
        if (original != null)
          ResponsiveRow(
            children: [
              _field('en ${original.romanization}', original.romanized),
              if (original.name != required) _field('en ${original.label.toLowerCase()}', original.name),
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
  const _TitleSortField({required this.value, required this.onChanged, this.hint});

  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  State<_TitleSortField> createState() => _TitleSortFieldState();
}

// Se usa poco: queda tras un botón mientras esté vacío.
class _TitleSortFieldState extends State<_TitleSortField> {
  late bool _open = widget.value.isNotEmpty || widget.hint != null;

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
      hint: widget.hint,
      floatLabel: widget.hint != null,
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
  const _BookTypeField({required this.value, required this.onChanged, this.hint, this.floatLabel = false});

  final String value;
  final String? hint;
  final bool floatLabel;
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
        decoration: InputDecoration(labelText: 'Tipo', hintText: hint, floatingLabelBehavior: floatLabel ? FloatingLabelBehavior.always : null),
      ),
    );
  }
}

// Solo se elige desde el calendario, que se despliega bajo el campo.
class _DateField extends StatefulWidget {
  const _DateField({required this.value, required this.onChanged, this.hint, this.floatLabel = false});

  final String value;
  final String? hint;
  final bool floatLabel;
  final ValueChanged<String> onChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  final _menu = MenuController();
  // Preferencia de la aplicación, no de la plantilla: restaurar la plantilla no la cambia.
  final _preferences = getIt.isRegistered<PreferencesRepository>() ? getIt<PreferencesRepository>() : null;
  late var _format = _preferences?.getDateFormat() ?? DateDisplayFormat.iso;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.value);
    return MenuAnchor(
      controller: _menu,
      menuChildren: [
        SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppPadding.medium + AppPadding.small, AppPadding.small, AppPadding.small, 0),
            child: Row(
              spacing: AppSpacing.medium,
              children: [
                Text('Mostrar como', style: Theme.of(context).textTheme.labelLarge),
                Expanded(
                  child: DropdownButton<DateDisplayFormat>(
                    value: _format,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [for (final f in DateDisplayFormat.values) DropdownMenuItem(value: f, child: Text(f.pattern))],
                    onChanged: (f) {
                      if (f == null) return;
                      setState(() => _format = f);
                      _preferences?.saveDateFormat(f);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 320,
          height: 340,
          // El menú ya usa el controlador de desplazamiento primario.
          child: PrimaryScrollController.none(
            child: CalendarDatePicker(
              initialDate: date != null && date.year >= 1900 && date.year <= 2100 ? date : DateTime.now(),
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
            hintText: widget.hint,
            floatingLabelBehavior: widget.floatLabel ? FloatingLabelBehavior.always : null,
            suffixIcon: date == null ? const Icon(Icons.calendar_today, size: 18) : IconButton(tooltip: 'Quitar fecha', icon: const Icon(Icons.close, size: 18), onPressed: () => widget.onChanged('')),
          ),
          child: Text(date == null ? '' : _format.format(date)),
        ),
      ),
    );
  }
}
