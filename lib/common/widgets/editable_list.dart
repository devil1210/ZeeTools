import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Lista de elementos con añadir, quitar y mover. Cada elemento recibe sus
// controles para colocarlos donde no resten espacio a los campos; [gapBuilder]
// dibuja lo que va entre el elemento [index] y el siguiente. Los campos
// internos no son controlados, así que cada cambio de estructura renueva sus
// claves para que tomen de nuevo su valor inicial.
class const EditableList<T>({
  super.key,
  required final List<T> items,
  required final ValueChanged<List<T>> onChanged,
  required final Widget Function(BuildContext context, int index, T item, ValueChanged<T> update, Widget controls) itemBuilder,
  required final T Function() createItem,
  required final String addLabel,
  final bool reorderable = true,
  final Widget Function(BuildContext context, int index)? gapBuilder,
}) extends StatefulWidget {
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
        for (final (i, item) in items.indexed) ...[
          KeyedSubtree(
            key: ValueKey('$_generation-$i'),
            child: widget.itemBuilder(
              context,
              i,
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
          if (widget.gapBuilder case final gap? when i < items.length - 1) gap(context, i),
        ],
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
class const EditableRow({super.key, required final Widget child, required final Widget controls}) extends StatelessWidget {
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
