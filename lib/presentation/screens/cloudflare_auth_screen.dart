import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CloudflareAuthScreen extends StatefulWidget {
  const CloudflareAuthScreen({
    super.key,
    required this.url,
    required this.domain,
  });

  final String url;
  final String domain;

  @override
  State<CloudflareAuthScreen> createState() => _CloudflareAuthScreenState();
}

class _CloudflareAuthScreenState extends State<CloudflareAuthScreen> {
  late final WebViewController _controller;
  bool _done = false;
  int _loadCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _onPageFinished(String url) async {
    _loadCount++;
    if (_done) return;
    if (!url.contains(widget.domain)) return;

    if (_loadCount < 2) return;

    try {
      final result = await _controller
          .runJavaScriptReturningResult('document.cookie');

      final cookieString = result.toString();
      if (cookieString.isEmpty || cookieString == '""') return;

      final cookies = _parseCookieString(cookieString);
      if (cookies.isEmpty) return;

      _done = true;
      if (mounted) {
        Navigator.of(context).pop<Map<String, String>>(cookies);
      }
    } catch (_) {}
  }

  Map<String, String> _parseCookieString(String raw) {
    final cookies = <String, String>{};
    final clean = raw.replaceAll('"', '');
    for (final part in clean.split(';')) {
      final trimmed = part.trim();
      final eq = trimmed.indexOf('=');
      if (eq > 0) {
        final name = trimmed.substring(0, eq).trim();
        final value = trimmed.substring(eq + 1).trim();
        if (name.isNotEmpty && value.isNotEmpty) {
          cookies[name] = value;
        }
      }
    }
    return cookies;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cloudflare 인증'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (!_done)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
