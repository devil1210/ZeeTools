import 'package:go_router/go_router.dart';

import 'presentation/views/epub_templater_view.dart';

abstract final class EpubTemplaterRoute {
  static const name = 'epub-templater';
  static const path = 'epub-templater';

  static GoRoute get route => GoRoute(
    name: name,
    path: path,
    builder: (_, _) => const EpubTemplaterView(),
  );
}
