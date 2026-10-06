import 'package:go_router/go_router.dart';

import 'presentation/views/epub_migrator_view.dart';

abstract final class EpubMigratorRoute {
  static const name = 'epub-migrator';
  static const path = 'epub-migrator';

  static GoRoute get route => GoRoute(
    name: name,
    path: path,
    builder: (_, _) => const EpubMigratorView(),
  );
}
