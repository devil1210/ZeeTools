import 'package:flutter/material.dart';

import '/features/zeepub_editorial/data/models/zeepub_series.dart';
import '/features/zeepub_editorial/data/models/zeepub_volume.dart';

/// Selector de destino en ZeePub: vincular a serie existente o registrar nueva serie.
class SeriesDestinationSelector extends StatelessWidget {
  final bool isCreatingNew;
  final ValueChanged<bool> onModeChanged;

  // Modo Existente
  final List<ZeepubSeries> seriesList;
  final ZeepubSeries? selectedSeries;
  final ValueChanged<ZeepubSeries?> onSeriesChanged;
  final List<ZeepubVolume> availableVolumes;
  final ZeepubVolume? selectedVolume;
  final ValueChanged<ZeepubVolume?> onVolumeChanged;

  // Modo Nueva Serie Controllers
  final TextEditingController newSeriesNameController;
  final TextEditingController newSeriesSpanishController;
  final TextEditingController newSeriesAuthorController;
  final TextEditingController newSeriesPublisherController;
  final TextEditingController newSeriesVolumeNumberController;
  final TextEditingController newSeriesVolumeTitleController;
  final TextEditingController newSeriesDescController;
  final String selectedBookType;
  final ValueChanged<String> onBookTypeChanged;

  static const List<String> bookTypes = [
    'Novela Ligera',
    'Novela Web',
    'Manga',
    'Manhwa',
    'Manhua',
    'Novela Visual',
    'Libro Tradicional',
  ];

  const SeriesDestinationSelector({
    super.key,
    required this.isCreatingNew,
    required this.onModeChanged,
    required this.seriesList,
    required this.selectedSeries,
    required this.onSeriesChanged,
    required this.availableVolumes,
    required this.selectedVolume,
    required this.onVolumeChanged,
    required this.newSeriesNameController,
    required this.newSeriesSpanishController,
    required this.newSeriesAuthorController,
    required this.newSeriesPublisherController,
    required this.newSeriesVolumeNumberController,
    required this.newSeriesVolumeTitleController,
    required this.newSeriesDescController,
    required this.selectedBookType,
    required this.onBookTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFF818CF8)),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('2. Destino en el Catálogo ZeePub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      'Elige si vinculas a una serie existente o das de alta una nueva serie',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Selector de Modo (Existente vs Nueva)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.library_books_rounded, size: 18),
                  label: Text('Serie Existente'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: Text('Crear Nueva Serie'),
                ),
              ],
              selected: {isCreatingNew},
              onSelectionChanged: (val) => onModeChanged(val.first),
            ),

            const SizedBox(height: 22),

            // Contenido según modo
            if (!isCreatingNew) ...[
              // Modo 1: Serie Existente
              DropdownButtonFormField<ZeepubSeries>(
                initialValue: selectedSeries,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Serie / Novela en Catálogo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bookmark_outline),
                ),
                items: [
                  for (final s in seriesList)
                    DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: onSeriesChanged,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ZeepubVolume>(
                initialValue: selectedVolume,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Volumen de Destino',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                items: [
                  for (final v in availableVolumes)
                    DropdownMenuItem(
                      value: v,
                      child: Text(
                        'Vol. ${v.volume != null ? (v.volume! % 1 == 0 ? v.volume!.toInt() : v.volume) : "?"} - ${v.title.isNotEmpty ? v.title : (v.spanishTitle.isNotEmpty ? v.spanishTitle : "Sin título")} (${v.bookHash.substring(0, v.bookHash.length > 8 ? 8 : v.bookHash.length)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onVolumeChanged,
              ),
            ] else ...[
              // Modo 2: Formulario de Nueva Serie
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_stories_outlined, size: 18, color: Color(0xFF818CF8)),
                        SizedBox(width: 8),
                        Text('Datos de la Nueva Serie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newSeriesNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Canónico de la Serie *',
                        hintText: 'Ej. Mushoku Tensei, Sword Art Online...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.title_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newSeriesSpanishController,
                            decoration: const InputDecoration(
                              labelText: 'Título en Español',
                              hintText: 'Opcional o traducido',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.translate_rounded, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedBookType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Obra',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final bt in bookTypes)
                                DropdownMenuItem(value: bt, child: Text(bt, overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) onBookTypeChanged(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newSeriesAuthorController,
                            decoration: const InputDecoration(
                              labelText: 'Autor',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: newSeriesPublisherController,
                            decoration: const InputDecoration(
                              labelText: 'Editorial / Sello',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.business_outlined, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.book_outlined, size: 18, color: Color(0xFF818CF8)),
                        SizedBox(width: 8),
                        Text('Datos del Volumen a Vincular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: newSeriesVolumeNumberController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Volumen # *',
                              hintText: '1',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.tag_rounded, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: newSeriesVolumeTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Título del Volumen',
                              hintText: 'Subtítulo o nombre del arco',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newSeriesDescController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Sinopsis / Descripción',
                        hintText: 'Resumen extraído del EPUB o escrito manualmente...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
