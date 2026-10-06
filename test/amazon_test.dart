import 'package:flutter_test/flutter_test.dart';
import 'package:zeetools/features/epub_templater/data/amazon_repo.dart';
import 'package:zeetools/features/epub_templater/domain/amazon_book.dart';
import 'package:zeetools/features/epub_templater/domain/book_metadata.dart';
import 'package:zeetools/features/epub_templater/domain/marc_relator.dart';
import 'package:zeetools/features/epub_templater/domain/title_languages.dart';

// Fragmentos de la ficha de Amazon Japón con la estructura que se lee.
const _page = '''
<html><body>
<div id="wayfinding-breadcrumbs_feature_div"><ul>
  <li><a href="#">Kindleストア</a></li><li><a href="#">Kindle本</a></li><li><a href="#">ライトノベル</a></li>
</ul></div>
<span id="productTitle" class="a-size-large">  盾の勇者の成り上がり 1【電子版書き下ろし付】 (MFブックス)  </span>
<div id="bylineInfo">
  <span class="author"><a class="a-link-normal" href="#">アネコ ユサギ</a><span class="contribution">(著),</span></span>
  <span class="author"><a class="a-link-normal" href="#">弥南 せいら</a><span class="contribution">(イラスト)</span></span>
</div>
<div id="seriesBulletWidget_feature_div"><a href="/dp/B0SERIES01">全22巻の第1巻: 盾の勇者の成り上がり</a></div>
<div id="tmmSwatches"><ul>
  <li><a href="/dp/B00GD14MOA"><span>Kindle版 (電子書籍)</span></a></li>
  <li><a href="/dp/4040661079"><span>単行本（ソフトカバー）</span></a></li>
</ul></div>
<img id="ebooksImgBlkFront" src="https://m.media-amazon.com/images/I/cover.jpg"/>
<div id="detailBullets_feature_div"><ul>
  <li><span><span>出版社 &rlm; : &lrm;</span><span>KADOKAWA</span></span></li>
  <li><span><span>発売日 &rlm; : &lrm;</span><span>2013/9/25</span></span></li>
  <li><span><span>言語 &rlm; : &lrm;</span><span>日本語</span></span></li>
</ul></div>
</body></html>
''';

void main() {
  test('lee título, personas, serie, formatos y detalles de la ficha', () {
    final book = parseAmazonPage('B00GD14MOA', _page);
    expect(book.title, '盾の勇者の成り上がり 1【電子版書き下ろし付】 (MFブックス)');
    expect([for (final c in book.contributors) (c.name, c.roles.join())], [('アネコ ユサギ', '著'), ('弥南 せいら', 'イラスト')]);
    expect((book.series, book.seriesIndex), ('盾の勇者の成り上がり', '1'));
    expect(book.formats, {'Kindle版': 'B00GD14MOA', '単行本（ソフトカバー）': '4040661079'});
    expect((book.publisher, book.date, book.language), ('KADOKAWA', '2013/9/25', '日本語'));
    expect(book.coverUrl, 'https://m.media-amazon.com/images/I/cover.jpg');
    expect(book.problems, isEmpty);
  });

  test('el título nativo pierde el sello, las marcas digitales y la serie repetida', () {
    expect(nativeTitle('盾の勇者の成り上がり 1【電子版書き下ろし付】 (MFブックス)'), '盾の勇者の成り上がり 1');
    expect(nativeTitle('涼宮ハルヒの退屈 「涼宮ハルヒ」シリーズ'), '涼宮ハルヒの退屈');
    expect(nativeTitle('フルメタル・パニック！疾るワン・ナイト・スタンド(新装版) フルメタル・パニック！(新装版)'), 'フルメタル・パニック！疾るワン・ナイト・スタンド(新装版)');
    expect(nativeTitle('バッカーノ！ 2002 【A side】 Bullet Garden'), 'バッカーノ！ 2002 【A side】 Bullet Garden');
    expect(nativeSeries('「涼宮ハルヒ」シリーズ'), '涼宮ハルヒ');
  });

  test('señala la edición inglesa, el manga y el ASIN inexistente', () {
    expect(const AmazonBook(asin: 'X', title: 'Psycome, Vol. 1 (light novel)', categories: ['本', '洋書']).problems, ['La ficha no es de la edición japonesa.']);
    expect(const AmazonBook(asin: 'X', title: '盾の勇者の成り上がり 1', categories: ['本', 'コミック']).problems, ['La ficha es de un manga, no de la novela.']);
    expect(const AmazonBook(asin: 'X', missing: true).problems, ['El ASIN no existe en Amazon Japón.']);
  });

  test('completa ISBN, títulos en japonés y nombres de autor e ilustrador sin pisar lo escrito', () {
    final book = parseAmazonPage('B00GD14MOA', _page).copyWith(isbn13: '9784040661071', isbn10: '4040661079');
    const m = BookMetadata(
      title: 'The Rising of the Shield Hero - Volumen 01 [RVN]',
      series: 'The Rising of the Shield Hero',
      altTitles: [LocalizedText(lang: 'es', text: 'El ascenso del héroe del escudo - Volumen 01')],
      actors: [
        Actor(name: 'Aneko Yusagi', roles: [MarcRelator.aut]),
        Actor(name: 'Minami Seira', altNames: [LocalizedText(lang: 'ja', text: '弥南せいら')], roles: [MarcRelator.ill]),
      ],
    );
    final (result, changes) = applyAmazon(m, book);
    expect((result.isbn13, result.isbn10), ('978-40-4066-107-1', '40-4066-107-9'));
    expect([for (final t in result.altTitles) (t.lang, t.text)], [('es', 'El ascenso del héroe del escudo - Volumen 01'), ('ja-Latn', ''), ('ja', '盾の勇者の成り上がり 1')]);
    expect(localizedText(result.altSeries, 'ja'), '盾の勇者の成り上がり');
    expect(result.actors.first.altNames, const [LocalizedText(lang: 'ja', text: 'アネコ ユサギ')]);
    expect(result.actors.last.altNames, const [LocalizedText(lang: 'ja', text: '弥南せいら')]);
    expect(changes, ['ISBN-13', 'ISBN-10', 'título en japonés', 'serie en japonés', 'autor en japonés']);
    expect(applyAmazon(result, book).$2, isEmpty);
  });
}
