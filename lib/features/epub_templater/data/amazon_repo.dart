import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import '/common/utils/either.dart';
import '../domain/amazon_book.dart';
import '../domain/book_metadata.dart';

const _headers = {
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
};
final amazonAsin = RegExp(r'^[A-Z0-9]{10}$');
// Ediciones en papel: su ficha trae el ISBN.
final _paper = RegExp(r'^(文庫|新書|単行本|ペーパーバック|大型本|Paperback|Hardcover|Mass Market Paperback)');

typedef AmazonResult = ({AmazonBook book, Uint8List? cover});

abstract interface class AmazonRepository {
  // La ficha se guarda en disco: el mismo ASIN no vuelve a consultarse.
  Future<Either<String, AmazonResult>> lookup(String asin, {AmazonStore store = AmazonStore.jp});
  // La ficha ya consultada, sin conectarse; null si no está en caché.
  AmazonResult? cached(String asin, {AmazonStore store = AmazonStore.jp});
}

String amazonUrl(String asin, {AmazonStore store = AmazonStore.jp}) => '${store.host}/dp/${asin.trim().toUpperCase()}';

class AmazonRepositoryImpl implements AmazonRepository {
  AmazonRepositoryImpl(this._cacheDir);

  final String _cacheDir;
  final _cookies = <String, Cookie>{};

  @override
  Future<Either<String, AmazonResult>> lookup(String asin, {AmazonStore store = AmazonStore.jp}) async {
    final code = asin.trim().toUpperCase();
    if (!amazonAsin.hasMatch(code)) return Either.left('«$asin» no es un ASIN.');
    try {
      final book = await _book(code, store);
      if (book.missing) return Either.right((book: book, cover: null));
      var full = book;
      if (book.isbn13.isEmpty && book.isbn10.isEmpty) {
        final paper = book.formats.entries.where((e) => _paper.hasMatch(e.key) && e.value != code).firstOrNull?.value;
        if (paper != null) {
          final edition = await _book(paper, store);
          full = _withPaperIsbn(book, edition, paper);
        }
      }
      return Either.right((book: full, cover: await _cover(code, full.coverUrl, store)));
    } on _Blocked catch (e) {
      return Either.left(e.message);
    } on SocketException {
      return Either.left('Sin conexión con ${store.label}.');
    } catch (e) {
      return Either.left('No se pudo leer la ficha de Amazon: $e');
    }
  }

  @override
  AmazonResult? cached(String asin, {AmazonStore store = AmazonStore.jp}) {
    final code = asin.trim().toUpperCase();
    final json = _cached(code, 'json', store);
    if (!amazonAsin.hasMatch(code) || !json.existsSync()) return null;
    try {
      var book = AmazonBook.fromJson(jsonDecode(json.readAsStringSync()) as Map<String, dynamic>);
      final paper = book.formats.entries.where((e) => _paper.hasMatch(e.key) && e.value != code).firstOrNull?.value;
      final edition = paper == null ? null : _cached(paper, 'json', store);
      if (book.isbn13.isEmpty && book.isbn10.isEmpty && edition != null && edition.existsSync()) {
        book = _withPaperIsbn(book, AmazonBook.fromJson(jsonDecode(edition.readAsStringSync()) as Map<String, dynamic>), paper!);
      }
      final cover = _cached(code, 'jpg', store);
      return (book: book, cover: cover.existsSync() ? cover.readAsBytesSync() : null);
    } catch (_) {
      return null;
    }
  }

  // Las fichas de Amazon Japón van en la raíz de la caché; las de otras tiendas, en su carpeta.
  File _cached(String asin, String ext, AmazonStore store) => File(store == AmazonStore.jp ? p.join(_cacheDir, '$asin.$ext') : p.join(_cacheDir, store.name, '$asin.$ext'));

  Future<AmazonBook> _book(String asin, AmazonStore store) async {
    final cache = _cached(asin, 'json', store);
    if (await cache.exists()) return AmazonBook.fromJson(jsonDecode(await cache.readAsString()) as Map<String, dynamic>);
    var (status, page) = await _get('${store.host}/dp/$asin', store);
    if (page.contains('validateCaptcha')) {
      if (!await _passCheck(page, store)) throw const _Blocked('Amazon pidió un captcha. Ábrelo en el navegador o inténtalo más tarde.');
      (status, page) = await _get('${store.host}/dp/$asin', store);
    }
    final AmazonBook book;
    if (status == 404) {
      book = AmazonBook(asin: asin, missing: true, store: store);
    } else if (status != 200 || !page.contains('productTitle')) {
      throw _Blocked('Amazon respondió $status; inténtalo más tarde.');
    } else {
      book = parseAmazonPage(asin, page, store: store);
    }
    await cache.parent.create(recursive: true);
    await cache.writeAsString(jsonEncode(book.toJson()));
    return book;
  }

  Future<Uint8List?> _cover(String asin, String url, AmazonStore store) async {
    final cache = _cached(asin, 'jpg', store);
    if (await cache.exists()) return cache.readAsBytes();
    if (url.isEmpty) return null;
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != 200) return null;
      final bytes = Uint8List.fromList(await response.expand((x) => x).toList());
      await cache.writeAsBytes(bytes);
      return bytes;
    } finally {
      client.close();
    }
  }

  Future<(int, String)> _get(String url, AmazonStore store, {bool follow = true}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = follow;
      _headers.forEach(request.headers.set);
      request.headers.set('accept-language', store.acceptLanguage);
      request.cookies.addAll(_cookies.values);
      final response = await request.close();
      for (final c in response.cookies) {
        _cookies[c.name] = Cookie(c.name, c.value);
      }
      return (response.statusCode, await response.transform(utf8.decoder).join());
    } finally {
      client.close();
    }
  }

  // La página de «seguir comprando» se envía tal cual; un captcha de imagen no se resuelve.
  Future<bool> _passCheck(String page, AmazonStore store) async {
    final form = html.parse(page).querySelector('form[action*="validateCaptcha"]');
    if (form == null || form.querySelector('img[src*="captcha"]') != null) return false;
    final params = {
      for (final input in form.querySelectorAll('input[name]')) input.attributes['name']!: input.attributes['value'] ?? '',
    };
    final action = Uri.parse('${store.host}${form.attributes['action']}').replace(queryParameters: params);
    final (status, _) = await _get(action.toString(), store, follow: false);
    return status >= 300 && status < 400 || status == 200;
  }
}

// El ISBN de la edición en papel; su ASIN de 10 cifras es el propio ISBN-10.
AmazonBook _withPaperIsbn(AmazonBook book, AmazonBook edition, String paper) =>
    book.copyWith(isbn13: edition.isbn13, isbn10: edition.isbn10.isNotEmpty ? edition.isbn10 : (RegExp(r'^\d{9}[\dX]$').hasMatch(paper) ? paper : ''));

class _Blocked implements Exception {
  const _Blocked(this.message);

  final String message;
}

String _text(Element? e) => (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

final _seriesJa = RegExp(r'全(\d+)巻の第([\d.]+)巻[:：]\s*(.+)');
final _seriesEn = RegExp(r'Book ([\d.]+) of (\d+)[:：]\s*(.+)');

AmazonBook parseAmazonPage(String asin, String page, {AmazonStore store = AmazonStore.jp}) {
  final doc = html.parse(page);
  final details = <String, String>{};
  for (final box in doc.querySelectorAll('div[id*="rpi-attribute"]')) {
    final label = _text(box.querySelector('.rpi-attribute-label'));
    final value = _text(box.querySelector('.rpi-attribute-value'));
    if (label.isNotEmpty && value.isNotEmpty) details[label] = value;
  }
  for (final li in doc.querySelectorAll('#detailBullets_feature_div li')) {
    final parts = li.querySelectorAll('span > span').map(_text).toList();
    if (parts.length >= 2) details[parts[0].replaceAll(RegExp(r'[\s:：‎‏]+$'), '').replaceAll(RegExp(r'[‎‏]'), '').trim()] = parts[1];
  }
  final formats = <String, String>{};
  for (final a in doc.querySelectorAll('#tmmSwatches a, [id*="tmm"] a[href*="/dp/"], [class*="swatch"] a[href*="/dp/"]')) {
    final name = RegExp(r'Kindle版|Audible版|文庫|新書|単行本(?:（ソフトカバー）)?|ペーパーバック|大型本|コミック|Kindle|Mass Market Paperback|Paperback|Hardcover').firstMatch(_text(a));
    final code = RegExp(r'/dp/([A-Z0-9]{10})').firstMatch(a.attributes['href'] ?? '');
    if (name != null && code != null) formats.putIfAbsent(name.group(0)!, () => code.group(1)!);
  }
  final series = _text(doc.querySelector('#seriesBulletWidget_feature_div a'));
  final ja = _seriesJa.firstMatch(series);
  final en = _seriesEn.firstMatch(series);
  final cover = doc.querySelector('#ebooksImgBlkFront, #landingImage, #imgBlkFront');
  return AmazonBook(
    asin: asin,
    store: store,
    title: _text(doc.getElementById('productTitle')),
    series: ja?.group(3) ?? en?.group(3) ?? series,
    seriesIndex: ja?.group(2) ?? en?.group(1) ?? '',
    categories: doc.querySelectorAll('#wayfinding-breadcrumbs_feature_div a').map(_text).toList(),
    coverUrl: cover?.attributes['data-old-hires']?.isNotEmpty == true ? cover!.attributes['data-old-hires']! : cover?.attributes['src'] ?? '',
    contributors: [
      for (final span in doc.querySelectorAll('#bylineInfo span.author'))
        if (_text(span.querySelector('a.a-link-normal')) case final name when name.isNotEmpty)
          AmazonContributor(
            name: name,
            roles: _text(span.querySelector('.contribution')).replaceAll(RegExp(r'[()（）,、]'), ' ').split(RegExp(r'\s+')).where((r) => r.isNotEmpty).toList(),
          ),
    ],
    description: _text(doc.querySelector('#bookDescription_feature_div .a-expander-content')),
    publisher: details['出版社'] ?? details['Publisher'] ?? '',
    date: details['発売日'] ?? details['出版日'] ?? details['Publication date'] ?? '',
    language: details['言語'] ?? details['Language'] ?? '',
    formats: formats,
    isbn13: (details['ISBN-13'] ?? '').replaceAll(RegExp(r'[^0-9X]'), ''),
    isbn10: (details['ISBN-10'] ?? '').replaceAll(RegExp(r'[^0-9X]'), ''),
  );
}
