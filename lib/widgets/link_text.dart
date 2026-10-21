import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// A segment of [LinkText.text]: either plain text or a tappable URL.
class LinkSegment {
  const LinkSegment.text(this.text) : url = null;
  const LinkSegment.link(this.text, this.url);

  final String text;
  final String? url;

  bool get isLink => url != null;
}

/// Splits [text] into plain and URL segments. Matches `http(s)://` and
/// `www.` prefixed URLs; trailing punctuation stays outside the link so
/// sentence-final URLs still read naturally.
List<LinkSegment> parseLinkSegments(String text) {
  if (text.isEmpty) return const [];
  final pattern = RegExp(
    r'''(?:(?:https?)://|www\.)[^\s<>"']+''',
    caseSensitive: false,
  );
  final segments = <LinkSegment>[];
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    var raw = match.group(0)!;
    var end = match.end;
    while (end > match.start && '.,;:!?)]}\'"'.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
      end--;
    }
    if (raw.isEmpty) continue;
    if (match.start > last) {
      segments.add(LinkSegment.text(text.substring(last, match.start)));
    }
    final url = raw.startsWith(RegExp('https?://', caseSensitive: false))
        ? raw
        : 'https://$raw';
    segments.add(LinkSegment.link(raw, url));
    last = end;
  }
  if (last < text.length) {
    segments.add(LinkSegment.text(text.substring(last)));
  }
  return segments;
}

/// Body/comment text with bare URLs rendered as tappable spans that open
/// the in-app browser (Chrome Custom Tabs on Android).
class LinkText extends StatefulWidget {
  const LinkText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  List<LinkSegment> _segments = const [];
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _syncSegments();
  }

  @override
  void didUpdateWidget(LinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _syncSegments();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _syncSegments() {
    _disposeRecognizers();
    _segments = parseLinkSegments(widget.text);
    for (final segment in _segments) {
      if (!segment.isLink) continue;
      final url = segment.url!;
      _recognizers.add(TapGestureRecognizer()..onTap = () => _openUrl(url));
    }
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        debugPrint('[LinkText] launchUrl returned false: $url');
      }
    } catch (e) {
      debugPrint('[LinkText] launchUrl failed for $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkColor = ShadTheme.of(context).colorScheme.primary;
    var linkIndex = 0;
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final segment in _segments)
            if (segment.isLink)
              TextSpan(
                text: segment.text,
                recognizer: _recognizers[linkIndex++],
                style:
                    widget.style?.copyWith(
                      color: linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ) ??
                    TextStyle(
                      color: linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
              )
            else
              TextSpan(text: segment.text),
        ],
      ),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
