import 'package:xml/xml.dart';

const xhtmlNs = 'http://www.w3.org/1999/xhtml';
const epubNs = 'http://www.idpf.org/2007/ops';
const headingTags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

// Las entidades de HTML (&nbsp;…) no existen en XML; se leen como sus caracteres.
XmlDocument parseXhtml(String text) => XmlDocument.parse(text, entityMapping: const XmlDefaultEntityMapping.html5());

String localName(XmlElement e) => e.name.local.toLowerCase();

bool isHeading(XmlNode n) => n is XmlElement && headingTags.contains(localName(n));

List<String> classesOf(XmlElement e) => (e.getAttribute('class') ?? '').split(RegExp(r'\s+')).where((c) => c.isNotEmpty).toList();

void setClasses(XmlElement e, List<String> classes) {
  final unique = [
    ...{...classes},
  ];
  if (unique.isEmpty) {
    e.removeAttribute('class');
  } else {
    e.setAttribute('class', unique.join(' '));
  }
}

String? epubTypeOf(XmlElement e) => e.getAttribute('epub:type') ?? e.getAttribute('type', namespaceUri: epubNs);

void setEpubType(XmlElement e, String? value) {
  e.removeAttribute('type', namespaceUri: epubNs);
  e.removeAttribute('epub:type');
  if (value != null && value.isNotEmpty) e.setAttribute('epub:type', value);
}

String normalizeSpace(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String textOf(XmlNode n) => normalizeSpace(n.innerText);

bool _isNoteRef(XmlElement a) => epubTypeOf(a) == 'noteref' || RegExp(r'#(nt|rf)\d+$').hasMatch(a.getAttribute('href') ?? '');

// Texto del encabezado con los saltos como espacios y sin las llamadas a notas.
String headingLabel(XmlElement h) {
  final b = StringBuffer();
  void walk(XmlNode n) {
    for (final c in n.children) {
      if (c is XmlText || c is XmlCDATA) {
        b.write(c.value);
      } else if (c is XmlElement) {
        if (localName(c) == 'br') {
          b.write(' ');
        } else if (!(localName(c) == 'a' && _isNoteRef(c))) {
          walk(c);
        }
      }
    }
  }

  walk(h);
  return normalizeSpace(b.toString());
}

String tocLabel(XmlElement h) {
  final title = normalizeSpace(h.getAttribute('title') ?? '');
  return title.isNotEmpty ? title : headingLabel(h);
}

// «Capítulo 1<br/>Título» sin title: «Capítulo 1: Título», como se escribe el índice.
String? colonLabel(XmlElement h) {
  if ((h.getAttribute('title') ?? '').isNotEmpty) return null;
  final breaks = h.descendants.whereType<XmlElement>().where((e) => localName(e) == 'br').toList();
  if (breaks.length != 1) return null;
  final b = StringBuffer();
  var before = '';
  void walk(XmlNode n) {
    for (final c in n.children) {
      if (c is XmlText) b.write(c.value);
      if (c is XmlElement) {
        if (identical(c, breaks.first)) {
          before = b.toString();
          b.clear();
        } else if (!(localName(c) == 'a' && _isNoteRef(c))) {
          walk(c);
        }
      }
    }
  }

  walk(h);
  final first = normalizeSpace(before);
  final rest = normalizeSpace(b.toString());
  if (first.isEmpty || rest.isEmpty || first.endsWith(':')) return null;
  return '$first: $rest';
}

XmlElement? bodyOf(XmlDocument doc) => doc.descendants.whereType<XmlElement>().where((e) => localName(e) == 'body').firstOrNull;

XmlElement? headOf(XmlDocument doc) => doc.descendants.whereType<XmlElement>().where((e) => localName(e) == 'head').firstOrNull;

Iterable<XmlElement> elementsOf(XmlNode n, String tag) => n.descendants.whereType<XmlElement>().where((e) => localName(e) == tag);

String escapeXml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
