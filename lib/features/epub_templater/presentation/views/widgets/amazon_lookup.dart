import 'package:flutter/material.dart';

import '/common/theme/app_dimensions.dart';
import '/common/utils/either.dart';
import '/common/utils/open_external.dart';
import '/inject_dependencies.dart';
import '../../../data/amazon_repo.dart';
import '../../../domain/amazon_book.dart';
import '../../../domain/book_metadata.dart';

// Consulta manual de la ficha de Amazon del ASIN (Japón, o Amazon.com para una novela que no es
// ligera): muestra la cubierta y los datos para validarla y completa los metadatos solo al aplicarla.
// [fields] recibe el botón de consultar, que va dentro del campo del ASIN mientras no haya ficha.
class const AmazonLookup({super.key, required final BookMetadata metadata, required final ValueChanged<BookMetadata Function(BookMetadata m)> onApply, required final Widget Function(Widget? lookup) fields}) extends StatefulWidget {
  @override
  State<AmazonLookup> createState() => _AmazonLookupState();
}

class _AmazonLookupState extends State<AmazonLookup> {
  AmazonResult? _result;
  String? _error;
  bool _loading = false;
  List<String>? _applied;

  @override
  void initState() {
    super.initState();
    _fromCache();
  }

  @override
  void didUpdateWidget(AmazonLookup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.asin != widget.metadata.asin || oldWidget.metadata.amazonStore != widget.metadata.amazonStore) _fromCache();
  }

  // Un ASIN ya consultado muestra su ficha sin volver a pedirla.
  void _fromCache() {
    if (!getIt.isRegistered<AmazonRepository>()) return;
    _result = getIt<AmazonRepository>().cached(widget.metadata.asin, store: widget.metadata.amazonStore);
    _applied = null;
  }

  @override
  Widget build(BuildContext context) {
    final asin = widget.metadata.asin.trim().toUpperCase();
    final store = widget.metadata.amazonStore;
    // La ficha de otro ASIN deja de mostrarse; lo ya aplicado se queda en los campos.
    final result = _result?.book.asin == asin && _result?.book.store == store ? _result : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium + AppSpacing.small,
      children: [
        widget.fields(
          result != null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: AppPadding.small),
                  child: TextButton.icon(
                    icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.travel_explore, size: 18),
                    label: const Text('Consultar'),
                    onPressed: _loading || !amazonAsin.hasMatch(asin)
                        ? null
                        : () async {
                            setState(() {
                              _loading = true;
                              _error = null;
                              _applied = null;
                            });
                            final lookup = await getIt<AmazonRepository>().lookup(asin, store: store);
                            if (!mounted) return;
                            setState(() {
                              _loading = false;
                              lookup.fold((e) => _error = e, (r) => _result = r);
                            });
                          },
                  ),
                ),
        ),
        if (result != null)
          _BookCard(
            lookup: result,
            applied: _applied,
            onApply: () {
              widget.onApply((m) => applyAmazon(m, result.book).$1);
              setState(() => _applied = applyAmazon(widget.metadata, result.book).$2);
            },
          )
        else if (_error case final error?)
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}

class const _BookCard({required final AmazonResult lookup, required final List<String>? applied, required final VoidCallback onApply}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final book = lookup.book;
    final theme = Theme.of(context);
    Widget line(String label, String value) => value.trim().isEmpty
        ? const SizedBox.shrink()
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          );
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.medium + AppPadding.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.large,
          children: [
            if (lookup.cover case final cover?)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Image.memory(cover, height: 180, fit: BoxFit.contain),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.small,
                children: [
                  if (book.missing) Text('ASIN ${book.asin}', style: theme.textTheme.titleMedium) else SelectableText(book.title, style: theme.textTheme.titleMedium),
                  for (final problem in book.problems)
                    Row(
                      spacing: AppSpacing.small,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                        Expanded(
                          child: Text(problem, style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ],
                    ),
                  if (!book.missing) ...[
                    for (final c in book.contributors) line(c.roles.map(amazonRoleLabel).join(', '), c.name),
                    line('Serie', [book.series, if (book.seriesIndex.isNotEmpty) 'volumen ${book.seriesIndex}'].where((x) => x.isNotEmpty).join(', ')),
                    line('Editorial', book.publisher),
                    line('Publicación', book.date),
                    line('ISBN', [book.isbn13, book.isbn10].where((x) => x.isNotEmpty).join(' · ')),
                    line('Categoría', book.categories.map(amazonCategoryLabel).join(' › ')),
                    const SizedBox(height: AppSpacing.small),
                    Wrap(
                      spacing: AppSpacing.medium,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(icon: const Icon(Icons.download_done, size: 18), label: const Text('Completar los metadatos'), onPressed: onApply),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Abrir en Amazon'),
                          onPressed: () => openExternal(amazonUrl(book.asin, store: book.store)),
                        ),
                        if (applied case final changes?) Text(changes.isEmpty ? 'No había nada que completar.' : 'Completado: ${changes.join(', ')}.'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
