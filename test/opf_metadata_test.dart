import 'package:flutter_test/flutter_test.dart';
import 'package:zeetools/features/epub_templater/data/opf_metadata.dart';
import 'package:zeetools/features/epub_templater/domain/book_metadata.dart';
import 'package:zeetools/features/epub_templater/domain/marc_relator.dart';
import 'package:zeetools/features/epub_templater/domain/metadata_field.dart';
import 'package:zeetools/features/epub_templater/domain/subjects.dart';

// Metadatos con la forma de la plantilla anterior: colección «set», urn:uri y prefijos xsd.
const _legacyOpf = '''<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" unique-identifier="BookId" xml:lang="es" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:language>es</dc:language>
    <dc:title>86 - Volumen 01 [ShinsengumiTL]</dc:title>
    <dc:date>2017-02-10T00:00:00Z</dc:date>
    <dc:creator id="creator01">Asato Asato</dc:creator>
    <meta property="role" refines="#creator01" scheme="marc:relators">aut</meta>
    <meta property="alternate-script" refines="#creator01" xml:lang="ja">安里 アサト</meta>
    <meta property="file-as" refines="#creator01">Asato, Asato</meta>
    <dc:type>Novela Ligera</dc:type>
    <dc:subject>Maduro</dc:subject>
    <dc:subject>Adultos/Seinen</dc:subject>
    <dc:subject>Acción</dc:subject>
    <dc:subject>Mecha</dc:subject>
    <dc:description>Sinopsis.</dc:description>
    <dc:contributor id="contrib1">Meraru</dc:contributor>
    <meta property="role" refines="#contrib1" scheme="marc:relators">trl</meta>
    <dc:publisher>Shinsengumi Translations</dc:publisher>
    <dc:identifier id="BookId">urn:uuid:5eee6da9-9951-4726-84a9-38383b22d39d</dc:identifier>
    <dc:identifier id="isbn13">urn:isbn:978-19-7530-312-9</dc:identifier>
    <meta property="identifier-type" refines="#isbn13" scheme="onix:codelist5">15</meta>
    <dc:identifier id="amazon-id">urn:amazon:B08CPBD8PF</dc:identifier>
    <meta property="identifier-type" refines="#amazon-id" scheme="xsd:string">amazon</meta>
    <dc:identifier id="uri-id">urn:uri:https://example.com/86</dc:identifier>
    <meta property="identifier-type" refines="#uri-id" scheme="xsd:string">uri</meta>
    <meta id="serie" property="belongs-to-collection">86 - EIGHTY-SIX [NL]</meta>
    <meta property="collection-type" refines="#serie">set</meta>
    <meta property="group-position" refines="#serie">1</meta>
    <meta content="86 - EIGHTY-SIX [NL]" name="calibre:series"/>
    <meta content="1" name="calibre:series_index"/>
    <meta content="9" name="calibre:rating"/>
    <meta property="dcterms:modified">2022-10-25T16:37:08Z</meta>
    <meta content="1.9.20" name="Sigil version"/>
    <meta name="cover" content="cover.jpg"/>
  </metadata>
  <manifest/>
</package>
''';

void main() {
  test('lee los metadatos de la plantilla anterior', () {
    final m = OpfMetadata(_legacyOpf).read();
    expect(m.identifier, '5eee6da9-9951-4726-84a9-38383b22d39d');
    expect(m.title, '86 - Volumen 01 [ShinsengumiTL]');
    expect(m.date, '2017-02-10T00:00:00Z');
    expect(m.actors, [
      const Actor(name: 'Asato Asato', fileAs: 'Asato, Asato', altNames: [LocalizedText(lang: 'ja', text: '安里 アサト')], roles: [MarcRelator.aut]),
      const Actor(name: 'Meraru', roles: [MarcRelator.trl]),
    ]);
    expect(m.demographic, Demographic.seinen);
    expect(m.genres, ['Acción']);
    expect(m.isbn13, '978-19-7530-312-9');
    expect(m.asin, 'B08CPBD8PF');
    expect(m.sourceUrl, 'https://example.com/86');
    expect((m.series, m.seriesIndex, m.rating), ('86 - EIGHTY-SIX [NL]', '1', 9));
  });

  test('reescribe solo los metadatos editables y conserva el resto', () {
    final opf = OpfMetadata(_legacyOpf);
    final m = opf.read().copyWith(seriesIndex: '2');
    final written = opf.write(_legacyOpf, m, now: DateTime.utc(2026, 1, 2, 3, 4, 5));

    for (final kept in ['<dc:subject>Mecha</dc:subject>', 'name="Sigil version"', '<meta name="cover" content="cover.jpg"/>', '<manifest/>']) {
      expect(written, contains(kept));
    }
    expect(written, contains('<meta refines="#serie" property="collection-type">series</meta>'));
    expect(written, contains('<meta refines="#serie" property="group-position">2</meta>'));
    expect(written, contains('<dc:identifier id="uri-id">https://example.com/86</dc:identifier>'));
    expect(written, contains('2026-01-02T03:04:05Z'));
    for (final gone in ['>set<', 'xsd:string', '2022-10-25', 'contrib1']) {
      expect(written, isNot(contains(gone)));
    }
    expect(OpfMetadata(written).read(), m);
  });

  test('los campos que difieren entre libros se vacían y solo se aplican si se editan', () {
    const a = BookMetadata(title: 'Vol 1', series: 'S', seriesIndex: '1', genres: ['Acción']);
    const b = BookMetadata(title: 'Vol 2', series: 'S', seriesIndex: '2', genres: ['Acción']);
    final (:common, :mixed) = commonMetadata([a, b]);
    expect(mixed, {MetadataField.title, MetadataField.seriesIndex});
    expect((common.title, common.seriesIndex, common.series), ('', '', 'S'));

    final form = common.copyWith(series: 'Serie', genres: ['Drama']);
    final changed = changedFields(common, form);
    expect(changed, {MetadataField.series, MetadataField.genres});
    expect(applyFields(b, form, changed), b.copyWith(series: 'Serie', genres: ['Drama']));
  });
}
