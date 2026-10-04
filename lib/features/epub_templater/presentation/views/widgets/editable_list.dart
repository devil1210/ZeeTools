import 'package:flutter/material.dart';

import '/common/theme/app_dimensions.dart';

// Lista de elementos con añadir, quitar y mover. Cada elemento recibe sus
// controles para colocarlos donde no resten espacio a los campos. Los campos
// internos no son controlados, así que cada cambio de estructura renueva sus
// claves para que tomen de nuevo su valor inicial.
class EditableList<T> extends StatefulWidget {
  const EditableList({
    super.key,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
    required this.createItem,
    required this.addLabel,
    this.reorderable = true,
  });

  final List<T> items;
  final ValueChanged<List<T>> onChanged;
  final Widget Function(BuildContext context, T item, ValueChanged<T> update, Widget controls) itemBuilder;
  final T Function() createItem;
  final String addLabel;
  final bool reorderable;

  @override
  State<EditableList<T>> createState() => _EditableListState<T>();
}

class _EditableListState<T> extends State<EditableList<T>> {
  int _generation = 0;

  void _restructure(List<T> items) {
    setState(() => _generation++);
    widget.onChanged(items);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium,
      children: [
        for (final (i, item) in items.indexed)
          KeyedSubtree(
            key: ValueKey('$_generation-$i'),
            child: widget.itemBuilder(
              context,
              item,
              (updated) => widget.onChanged([...items]..[i] = updated),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.reorderable) ...[
                    IconButton(
                      tooltip: 'Subir',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: i == 0
                          ? null
                          : () => _restructure(
                              [...items]
                                ..removeAt(i)
                                ..insert(i - 1, item),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Bajar',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: i == items.length - 1
                          ? null
                          : () => _restructure(
                              [...items]
                                ..removeAt(i)
                                ..insert(i + 1, item),
                            ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _restructure([...items]..removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(widget.addLabel),
          onPressed: () => _restructure([...items, widget.createItem()]),
        ),
      ],
    );
  }
}

// Fila habitual: los campos ocupan el ancho y los controles quedan a la derecha.
class EditableRow extends StatelessWidget {
  const EditableRow({super.key, required this.child, required this.controls});

  final Widget child;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        controls,
      ],
    );
  }
}
