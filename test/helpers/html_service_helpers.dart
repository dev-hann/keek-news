import 'package:html/dom.dart';
import 'package:keek_news/service/html_service.dart';

/// Multi-candidate selector helpers shared by test fakes that extend
/// HtmlService. Production code uses DioHtmlService; tests usually
/// substitute a tiny fixture-backed fake. Pulling these four methods into a
/// single mixin keeps the eight-or-so fakes in lockstep with the abstract
/// surface without copy-pasting the bodies into every test file.
mixin HtmlServiceMultiCandidateMixin on HtmlService {
  @override
  int statOfAny(Element? parent, Iterable<String> selectors) {
    if (parent == null) return 0;
    for (final s in selectors) {
      final value = extractNumber(textOf(parent.querySelector(s)));
      if (value != 0) return value;
    }
    return 0;
  }

  @override
  Element? queryFirst(Element? root, Iterable<String> selectors) {
    if (root == null) return null;
    for (final s in selectors) {
      final hit = root.querySelector(s);
      if (hit != null) return hit;
    }
    return null;
  }

  @override
  String textOfAny(Element? root, Iterable<String> selectors) =>
      textOf(queryFirst(root, selectors));

  @override
  String? attrOfAny(
    Element? root,
    Iterable<({String selector, String attr})> pairs,
  ) {
    if (root == null) return null;
    for (final p in pairs) {
      for (final el in root.querySelectorAll(p.selector)) {
        final v = el.attributes[p.attr];
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }
}
