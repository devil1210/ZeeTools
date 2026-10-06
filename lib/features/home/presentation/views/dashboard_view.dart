import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/features/epub_migrator/epub_migrator_route.dart';
import '/features/epub_templater/epub_templater_route.dart';
import '/features/image_optimizer/image_optimizer_route.dart';
import '/features/metadata_editor/metadata_editor_route.dart';
import '/features/search_replace/search_replace_route.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.goNamed(SearchReplaceRoute.name),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.find_replace_rounded, size: 36),
                  SizedBox(height: 8),
                  Text('Búsqueda y Reemplazo', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.goNamed(ImageOptimizerRoute.name),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_size_select_large_rounded, size: 36),
                  SizedBox(height: 8),
                  Text('Optimizador de Imágenes', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.goNamed(EpubTemplaterRoute.name),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Plantillas EPUB', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.goNamed(MetadataEditorRoute.name),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Editor de metadatos', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.goNamed(EpubMigratorRoute.name),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_fix_high_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Migrar al template nuevo', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
