import 'dart:convert';

import 'package:charset_converter/charset_converter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/service/html_service.dart';

typedef CharsetDecode =
    Future<String> Function(String encoding, Uint8List bytes);

Future<String> _defaultCharsetDecode(String encoding, Uint8List bytes) =>
    CharsetConverter.decode(encoding, bytes);

const _diagnosticHeaderAllowlist = <String>{
  'server',
  'cf-ray',
  'cf-mitigated',
  'retry-after',
  'content-type',
  'date',
};

const _maxSnippetBytes = 2000;
const _maxSnippetChars = 500;

class DioHtmlService extends HtmlService {
  DioHtmlService({
    required Dio dio,
    required String encoding,
    CharsetDecode decode = _defaultCharsetDecode,
  }) : _dio = dio,
       _encoding = encoding,
       _decode = decode;

  final Dio _dio;
  final String _encoding;
  final CharsetDecode _decode;

  @override
  Future<String> get(String path) async {
    try {
      final response = await _dio.get<List<int>>(path);
      final bytes = response.data ?? <int>[];
      return _decode(_encoding, Uint8List.fromList(bytes));
    } on DioException catch (e) {
      throw _toFailure(e);
    }
  }

  Failure _toFailure(DioException e) {
    final diag = _buildDiagnostics(e);
    if (diag != null) {
      debugPrint(
        '[HttpDiag] ${diag.statusCode ?? '?'} '
        '${e.requestOptions.method} '
        '${diag.requestPath ?? e.requestOptions.path} '
        '${diag.headers['server'] ?? ''} '
        '${diag.headers['cf-ray'] ?? ''}',
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(e.message ?? e.type.name, http: diag);
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ServerFailure(e.message ?? e.type.name, http: diag);
    }
  }

  HttpDiagnostics? _buildDiagnostics(DioException e) {
    final response = e.response;
    if (response == null) return null;

    final picked = <String, String>{};
    for (final name in _diagnosticHeaderAllowlist) {
      final value = response.headers.value(name);
      if (value != null && value.isNotEmpty) {
        picked[name] = value;
      }
    }

    final body = response.data;
    var snippet = '';
    if (body is List<int>) {
      final truncated = body.length > _maxSnippetBytes
          ? body.sublist(0, _maxSnippetBytes)
          : body;
      snippet = utf8.decode(truncated, allowMalformed: true);
      if (snippet.length > _maxSnippetChars) {
        snippet = snippet.substring(0, _maxSnippetChars);
      }
    }

    return HttpDiagnostics(
      statusCode: response.statusCode,
      headers: picked,
      bodySnippet: snippet,
      requestPath: e.requestOptions.path,
    );
  }

  @override
  int extractNumber(String? text) {
    if (text == null) return 0;
    final digits = text.replaceAll(RegExp('[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  @override
  String textOf(dom.Element? element) => element?.text.trim() ?? '';

  @override
  String? attrOf(dom.Element? element, String name) =>
      element?.attributes[name];

  @override
  int statOf(dom.Element? parent, String selector) {
    if (parent == null) return 0;
    return extractNumber(textOf(parent.querySelector(selector)));
  }

  @override
  int statOfAny(dom.Element? parent, Iterable<String> selectors) {
    if (parent == null) return 0;
    for (final selector in selectors) {
      final value = extractNumber(textOf(parent.querySelector(selector)));
      if (value != 0) return value;
    }
    return 0;
  }

  @override
  dom.Element? queryFirst(dom.Element? root, Iterable<String> selectors) {
    if (root == null) return null;
    for (final s in selectors) {
      final hit = root.querySelector(s);
      if (hit != null) return hit;
    }
    return null;
  }

  @override
  String textOfAny(dom.Element? root, Iterable<String> selectors) {
    return textOf(queryFirst(root, selectors));
  }

  @override
  String? attrOfAny(
    dom.Element? root,
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
