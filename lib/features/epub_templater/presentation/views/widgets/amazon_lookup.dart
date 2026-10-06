import 'package:flutter/material.dart';

import '/common/theme/app_dimensions.dart';
import '/common/utils/either.dart';
import '/common/utils/open_external.dart';
import '/inject_dependencies.dart';
import '../../../data/amazon_repo.dart';
import '../../../domain/amazon_book.dart';
import '../../../domain/book_metadata.dart';

// Consulta manual de la ficha de Amazon Japón del ASIN: muestra la cubierta y
// los datos para validarla y completa los metadatos solo al aplicarla.
class AmazonLookup extends StatefulWidget {
  const AmazonLookup({super.key, required this.asin, required this.metadata, required this.onApply});

  final String asin;
  final BookMetadata metadata;
  final ValueChanged<BookMetadata Function(BookMetadata m)> onApply;

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
    if (oldWidget.asin != widget.asin) _fromCache();
  }

  // Un ASIN ya consultado muestra su ficha sin volver a pedirla.
  void _fromCache() {
    if (!getIt.isRegistered<AmazonRepository>()) return;
    final cached = getIt<AmazonRepository>().cached(widget.asin);
    if (cached != null) {
      _result = cached;
      _applied = null;
    }
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
      _applied = null;
    });
    final result = await getIt<AmazonRepository>().lookup(widget.asin);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((e) => _error = e, (r) => _result = r);
    });
  }

  void _apply(AmazonBook book) {
    final (_, changes) = applyAmazon(widget.metadata, book);
    widget.onApply((m) => applyAmazon(m, book).$1);
    setState(() => _applied = changes);
  }

  @override
  Widget build(BuildContext context) {
    final asin = widget.asin.trim().toUpperCase();
    // La ficha de otro ASIN deja de mostrarse; lo ya aplicado se queda en los campos.
    final result = _result?.book.asin == asin ? _result : null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        if (result == null)
          Row(
            spacing: AppSpacing.medium,
            children: [
              OutlinedButton.icon(
                icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.travel_explore, size: 18),
                label: const Text('Consultar Amazon Japón'),
                onPressed: _loading || !amazonAsin.hasMatch(asin) ? null : _lookup,
              ),
              if (_error case final error?) Expanded(child: Text(error, style: TextStyle(color: theme.colorScheme.error))),
            ],
          ),
        if (result != null) _BookCard(lookup: result, applied: _applied, onApply: () => _apply(result.book)),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.lookup, required this.applied, required this.onApply});

  final AmazonResult lookup;
  final List<String>? applied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final book = lookup.book;
    final theme = Theme.of(context);
    final problems = book.problems;
    Widget line(String label, String value) => value.trim().isEmpty
        ? const SizedBox.shrink()
        : Text.rich(TextSpan(children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: value)]));
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
                child: Image.memory(cover, height: 200, fit: BoxFit.contain),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.small,
                children: [
                  if (book.missing) Text('ASIN ${book.asin}', style: theme.textTheme.titleMedium) else SelectableText(book.title, style: theme.textTheme.titleMedium),
                  for (final problem in problems)
                    Row(
                      spacing: AppSpacing.small,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                        Expanded(child: Text(problem, style: TextStyle(color: theme.colorScheme.error))),
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
                        OutlinedButton.icon(icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Abrir en Amazon'), onPressed: () => openExternal(amazonUrl(book.asin))),
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
