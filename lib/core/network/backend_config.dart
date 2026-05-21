import 'dart:io';

import 'package:flutter/foundation.dart';

String resolveBackendBaseUrl() {
  const configured = String.fromEnvironment('BACKEND_BASE_URL');
  final trimmed = configured.trim();
  if (trimmed.isNotEmpty) {
    return normalizeBackendBaseUrl(trimmed);
  }

  if (kReleaseMode && (Platform.isIOS || Platform.isAndroid)) {
    throw const FormatException(
      'Release build is missing BACKEND_BASE_URL. '
      'Please build with --dart-define=BACKEND_BASE_URL=https://你的后端域名',
    );
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://127.0.0.1:3000';
}

String normalizeBackendBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('BACKEND_BASE_URL is empty.');
  }

  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
