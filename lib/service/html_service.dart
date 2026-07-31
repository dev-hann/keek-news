import 'package:html/dom.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';

abstract class HtmlService {
  Future<String> get(String path);

  int extractNumber(String? text);

  String textOf(Element? element);

  String? attrOf(Element? element, String name);

  int statOf(Element? parent, String selector);

  DateTime? parseDate(String text);

  ContentScanResult scanContent(Element container);

  ContentScanResult scanContentFull(Document doc, Element contentEl);

  List<ContentBlock> scanContentCompact(Element container);
}
