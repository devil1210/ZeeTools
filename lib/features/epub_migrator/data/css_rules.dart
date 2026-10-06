// Regla de una hoja de estilos. [context]: el @media o @supports que la contiene,
// vacío en el nivel superior. [own]: está tras el comentario «Fin del CSS», donde
// cada libro escribe lo suyo.
typedef CssRule = ({String context, String prelude, String body, bool own});

final _comment = RegExp(r'/\*.*?\*/', dotAll: true);
final _endMarker = RegExp(r'/\*\s*Fin del CSS\s*\*/', caseSensitive: false);
final _className = RegExp(r'\.([A-Za-z_][\w-]*)');

List<CssRule> parseCss(String css) {
  final end = _endMarker.firstMatch(css)?.start ?? css.length;
  // Los comentarios se vacían sin mover las posiciones, para saber qué reglas van tras la marca.
  final text = css.replaceAllMapped(_comment, (m) => ' ' * m[0]!.length);
  final rules = <CssRule>[];
  void parse(int from, int to, String context) {
    var i = from;
    while (i < to) {
      final open = text.indexOf('{', i);
      final semicolon = text.indexOf(';', i);
      if (open < 0 || open >= to) return;
      // @import y @charset terminan en punto y coma, sin bloque.
      if (semicolon >= 0 && semicolon < open && text.substring(i, semicolon).trim().startsWith('@')) {
        i = semicolon + 1;
        continue;
      }
      final close = _matching(text, open);
      final prelude = text.substring(i, open).trim().replaceAll(RegExp(r'\s+'), ' ');
      if (RegExp(r'^@(media|supports)\b').hasMatch(prelude)) {
        parse(open + 1, close, prelude);
      } else if (prelude.isNotEmpty) {
        rules.add((context: context, prelude: prelude, body: text.substring(open + 1, close).trim(), own: open > end));
      }
      i = close + 1;
    }
  }

  parse(0, text.length, '');
  return rules;
}

int _matching(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}' && --depth == 0) return i;
  }
  return text.length;
}

// Declaraciones en orden; los «;» dentro de paréntesis (url(data:…)) no separan.
List<(String, String)> declarations(String body) {
  final out = <(String, String)>[];
  var depth = 0;
  var start = 0;
  void take(int end) {
    final decl = body.substring(start, end).trim();
    final colon = decl.indexOf(':');
    if (colon > 0) out.add((decl.substring(0, colon).trim().toLowerCase(), decl.substring(colon + 1).trim()));
  }

  for (var i = 0; i < body.length; i++) {
    if (body[i] == '(') depth++;
    if (body[i] == ')') depth--;
    if (body[i] == ';' && depth == 0) {
      take(i);
      start = i + 1;
    }
  }
  take(body.length);
  return out;
}

String? declaration(String body, String name) => declarations(body).where((d) => d.$1 == name).lastOrNull?.$2;

List<String> selectorsOf(String prelude) => prelude.startsWith('@') ? const [] : prelude.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

List<String> classNames(String selector) => [for (final m in _className.allMatches(selector)) m[1]!];

List<String> fontFamilies(String value) => value.split(',').map((f) => f.trim().replaceAll(RegExp(r'''^["']|["']$'''), '')).where((f) => f.isNotEmpty).toList();

String prettyRule(String prelude, String body) {
  final decls = declarations(body);
  final selectors = prelude.startsWith('@') ? [prelude] : selectorsOf(prelude);
  return '${selectors.join(',\n')} {\n${decls.map((d) => '  ${d.$1}: ${d.$2};\n').join()}}';
}
