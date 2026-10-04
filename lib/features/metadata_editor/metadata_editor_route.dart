import 'package:go_router/go_router.dart';

import 'presentation/views/metadata_editor_view.dart';

abstract final class MetadataEditorRoute {
  static const name = 'metadata-editor';
  static const path = 'metadata-editor';

  static GoRoute get route => GoRoute(
    name: name,
    path: path,
    builder: (_, _) => const MetadataEditorView(),
  );
}
