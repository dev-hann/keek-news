import 'dart:async';

import 'package:flutter/foundation.dart';

class RetryController extends ChangeNotifier {
  RetryController({
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  });

  final int maxAttempts;
  final Duration retryDelay;

  int _attempt = 0;
  bool _failed = false;
  Timer? _timer;

  int get attempt => _attempt;
  bool get hasError => _failed;
  bool get canAutoRetry => _failed && _attempt < maxAttempts - 1;
  bool get isExhausted => _failed && _attempt >= maxAttempts - 1;

  void recordFailure() {
    _failed = true;
    if (_attempt >= maxAttempts - 1) {
      notifyListeners();
      return;
    }
    final next = _attempt + 1;
    _timer?.cancel();
    _timer = Timer(retryDelay, () {
      _timer = null;
      _attempt = next;
      _failed = false;
      notifyListeners();
    });
  }

  void manualRetry() {
    _timer?.cancel();
    _timer = null;
    _attempt = 0;
    _failed = false;
    notifyListeners();
  }

  void resetForUrl(String newUrl, {required String currentUrl}) {
    if (newUrl == currentUrl) return;
    _timer?.cancel();
    _timer = null;
    _attempt = 0;
    _failed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
