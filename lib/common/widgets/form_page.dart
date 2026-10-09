import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_dimensions.dart';
import 'form_section.dart';

const _maxContentWidth = 1100.0;
const _minContentWidth = 760.0;
const _indexWidth = 220.0;
// Deja libre el botón flotante al final.
const _bottomPadding = 96.0;

// Secciones de un formulario con un ancho de lectura cómodo. Con [showIndex] y espacio suficiente,
// un índice lateral lleva a cada sección y marca la que se está viendo; para poder saltar a
// cualquiera, todas se construyen a la vez en lugar de a medida que aparecen.
class const FormPage({super.key, required final List<FormSection> sections, final bool showIndex = false}) extends StatefulWidget {
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[];
  var _current = 0;
  // Mientras se desplaza hasta la sección elegida en el índice, el índice no sigue al desplazamiento.
  var _jumping = false;

  @override
  void initState() {
    super.initState();
    _syncKeys();
    _scroll.addListener(_follow);
  }

  @override
  void didUpdateWidget(FormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncKeys() {
    final count = widget.sections.length;
    if (_keys.length > count) _keys.removeRange(count, _keys.length);
    while (_keys.length < count) {
      _keys.add(GlobalKey());
    }
  }

  // La sección actual es la última cuyo comienzo ya ha llegado arriba, o la última al final del todo.
  void _follow() {
    if (_jumping) return;
    final position = _scroll.position;
    final current = position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent
        ? _keys.length - 1
        : max(
            0,
            _keys.lastIndexWhere(
              (key) => switch (key.currentContext?.findRenderObject()) {
                final RenderBox box => RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset <= position.pixels + AppSpacing.large,
                _ => false,
              },
            ),
          );
    if (current != _current) setState(() => _current = current);
  }

  Future<void> _jump(int index) async {
    setState(() {
      _current = index;
      _jumping = true;
    });
    // Solo se desplaza este formulario: ensureVisible movería también las pestañas que lo contienen.
    if (_keys[index].currentContext?.findRenderObject() case final RenderBox box) {
      final offset = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset.clamp(0.0, _scroll.position.maxScrollExtent);
      await _scroll.animateTo(offset, duration: Durations.medium2, curve: Curves.easeInOut);
    }
    _jumping = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final indexed = widget.showIndex && widget.sections.length > 1 && constraints.maxWidth >= _indexWidth + _minContentWidth;
        final gutter = max(AppPadding.large, (constraints.maxWidth - (indexed ? _indexWidth : 0) - _maxContentWidth) / 2);
        final content = SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(indexed ? AppPadding.large : gutter, AppPadding.large, gutter, _bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, section) in widget.sections.indexed) KeyedSubtree(key: _keys[i], child: section),
            ],
          ),
        );
        if (!indexed) return content;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppPadding.large, 0, AppPadding.large),
              child: SizedBox(
                width: _indexWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.tiny,
                  children: [
                    for (final (i, section) in widget.sections.indexed)
                      ListTile(
                        dense: true,
                        selected: i == _current,
                        selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
                        leading: section.icon == null ? null : Icon(section.icon, size: 20),
                        title: Text(section.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: section.issues > 0 ? IssueCount(count: section.issues) : null,
                        onTap: () => _jump(i),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
