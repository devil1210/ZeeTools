import 'package:freezed_annotation/freezed_annotation.dart';

import '/common/utils/input_formatters.dart';
import 'book_metadata.dart';
import 'marc_relator.dart';
import 'title_languages.dart';

part 'amazon_book.freezed.dart';
part 'amazon_book.g.dart';

@Freezed()
abstract class AmazonContributor with _$AmazonContributor {
  const factory AmazonContributor({
    required String name,
    // Funciones en japonés tal como las escribe la ficha (著, イラスト…).
    @Default([]) List<String> roles,
  }) = _AmazonContributor;

  factory AmazonContributor.fromJson(Map<String, dynamic> json) => _$AmazonContributorFromJson(json);
}

// Ficha de un producto de Amazon Japón.
@Freezed()
abstract class AmazonBook with _$AmazonBook {
  const factory AmazonBook({
    required String asin,
    // El ASIN no existe en Amazon Japón.
    @Default(false) bool missing,
    @Default('') String title,
    @Default('') String series,
    @Default('') String seriesIndex,
    @Default([]) List<String> categories,
    @Default('') String coverUrl,
    @Default([]) List<AmazonContributor> contributors,
    @Default('') String description,
    @Default('') String publisher,
    @Default('') String date,
    @Default('') String language,
    // Formato (Kindle版, 文庫…) → ASIN de esa edición.
    @Default({}) Map<String, String> formats,
    @Default('') String isbn13,
    @Default('') String isbn10,
  }) = _AmazonBook;

  factory AmazonBook.fromJson(Map<String, dynamic> json) => _$AmazonBookFromJson(json);
}

const _roles = {
  '著': MarcRelator.aut,
  '作': MarcRelator.aut,
  '著者': MarcRelator.aut,
  '文': MarcRelator.aut,
  'Author': MarcRelator.aut,
  'イラスト': MarcRelator.ill,
  '絵': MarcRelator.ill,
  'イラストレーター': MarcRelator.ill,
  'Illustrator': MarcRelator.ill,
  '原作': MarcRelator.ant,
  'キャラクター原案': MarcRelator.art,
};

const _roleLabels = {
  '著': 'Autor',
  '作': 'Autor',
  '著者': 'Autor',
  '文': 'Autor',
  'イラスト': 'Ilustrador',
  '絵': 'Ilustrador',
  'イラストレーター': 'Ilustrador',
  '翻訳': 'Traductor',
  '訳': 'Traductor',
  '原作': 'Obra original',
  '原案': 'Idea original',
  'キャラクター原案': 'Diseño de personajes',
  '監修': 'Supervisión',
  '編集': 'Edición',
  'デザイン': 'Diseño',
  '漫画': 'Manga',
  '作画': 'Dibujo',
  '企画': 'Planificación',
};

const _categoryLabels = {
  '本': 'Libros',
  'Kindleストア': 'Tienda Kindle',
  'Kindle本': 'Libros Kindle',
  '洋書': 'Libros extranjeros',
  'コミック・ラノベ・BL': 'Cómics, novelas ligeras y BL',
  'ライトノベル': 'Novela ligera',
  'コミック': 'Cómic',
  'マンガ': 'Manga',
  '文学・評論': 'Literatura y crítica',
  '小説・文芸': 'Novela y literatura',
  '日本の小説・文芸': 'Novela japonesa',
  '文芸作品': 'Obras literarias',
  'ボーイズラブ': 'BL',
  'ティーンズラブ': 'TL',
  'ゲーム攻略本': 'Guías de videojuegos',
  'アニメーション': 'Animación',
};

// Función o categoría de la ficha en español cuando se conoce; si no, como la escribe Amazon.
String amazonRoleLabel(String role) => _roleLabels[role] ?? role;

String amazonCategoryLabel(String category) => _categoryLabels[category] ?? category;

final _label = RegExp(r'\s*[（(][^()（）]*(?:文庫版?|ノベルス?|ブックス|BOOKS|Books|ノベル|NOVELS|Novels|文芸)[^()（）]*[)）]\s*');
final _editionMark = RegExp(r'\s*【[^】]*(?:電子|特典|ＳＳ|SS|[Kk]indle|限定|書き下ろし|付)[^】]*】|\s*電子書籍特典付き$|\s*電子DX版$');
final _seriesTail = RegExp(r'\s+「[^」]*」シリーズ$');
final _cjk = RegExp(r'[぀-ヿ㐀-鿿가-힯]');

// Título sin el sello, las marcas de la edición digital ni la serie que Amazon repite al final.
String nativeTitle(String title) {
  var t = title.replaceAll(_editionMark, '').replaceAll(_label, ' ').replaceAll(_seriesTail, '').replaceFirst(RegExp(r'^\s*【[^】]*】\s*'), '').trim();
  final space = t.lastIndexOf(RegExp(r'[ 　]'));
  if (space > 0) {
    final head = t.substring(0, space).trim();
    final tail = t.substring(space + 1).trim();
    String bare(String s) => s.replaceAll(RegExp(r'[!！?？\s　]'), '').toLowerCase();
    if (tail.length >= 3 && bare(head).contains(bare(tail).split(RegExp(r'[(（]')).first)) t = head;
  }
  return t;
}

String nativeSeries(String series) {
  final m = RegExp(r'^「([^」]*)」シリーズ$').firstMatch(series.trim());
  return nativeTitle(m?.group(1) ?? series);
}

extension AmazonBookX on AmazonBook {
  // Edición japonesa (no la inglesa que también vende Amazon Japón) y de novela, no de manga.
  List<String> get problems => [
    if (missing) 'El ASIN no existe en Amazon Japón.',
    if (!missing && (categories.any((c) => c.contains('洋書')) || (language.isNotEmpty && !language.contains('日本語')) || !_cjk.hasMatch(title)))
      'La ficha no es de la edición japonesa.',
    if (!missing && categories.isNotEmpty && RegExp(r'コミック|マンガ|漫画').hasMatch(categories.last)) 'La ficha es de un manga, no de la novela.',
  ];

  MarcRelator? roleOf(AmazonContributor c) => c.roles.map((r) => _roles[r]).nonNulls.firstOrNull;
}

// Lo que la ficha completa en los metadatos: ISBN, título y serie en japonés y
// el nombre japonés de autor e ilustrador. Devuelve también qué cambió.
(BookMetadata, List<String>) applyAmazon(BookMetadata m, AmazonBook book) {
  final changes = <String>[];
  var result = m;
  if (book.isbn13.isNotEmpty && formatIsbn(book.isbn13, isbn13Groups) != m.isbn13) {
    result = result.copyWith(isbn13: formatIsbn(book.isbn13, isbn13Groups));
    changes.add('ISBN-13');
  }
  if (book.isbn10.isNotEmpty && formatIsbn(book.isbn10, isbn10Groups) != m.isbn10) {
    result = result.copyWith(isbn10: formatIsbn(book.isbn10, isbn10Groups));
    changes.add('ISBN-10');
  }

  final title = nativeTitle(book.title);
  if (_cjk.hasMatch(title)) {
    final original = originalLanguageOf(result.altTitles) ?? originalLanguageOf(result.altSeries);
    if (original == null || original == OriginalLanguage.ja) {
      if (localizedText(result.altTitles, 'ja').trim().isEmpty) {
        result = result.copyWith(altTitles: withLocalizedText(withOriginalLanguage(result.altTitles, OriginalLanguage.ja), 'ja', title));
        changes.add('título en japonés');
      }
      final series = nativeSeries(book.series);
      if (result.hasSeries && _cjk.hasMatch(series) && localizedText(result.altSeries, 'ja').trim().isEmpty) {
        result = result.copyWith(altSeries: withLocalizedText(withOriginalLanguage(result.altSeries, OriginalLanguage.ja), 'ja', series));
        changes.add('serie en japonés');
      }
    }
  }

  final actors = [...result.actors];
  for (final c in book.contributors) {
    final role = book.roleOf(c);
    if (role == null) continue;
    final holders = [
      for (final (i, a) in actors.indexed)
        if (a.roles.contains(role)) i,
    ];
    if (holders.length != 1 || localizedText(actors[holders.first].altNames, 'ja').trim().isNotEmpty) continue;
    final actor = actors[holders.first];
    actors[holders.first] = actor.copyWith(altNames: [...actor.altNames.where((t) => t.lang.trim().toLowerCase() != 'ja'), LocalizedText(lang: 'ja', text: c.name)]);
    changes.add('${role.label.toLowerCase()} en japonés');
  }
  return (result.copyWith(actors: actors), changes);
}
