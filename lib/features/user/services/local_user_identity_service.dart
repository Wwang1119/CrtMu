import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalUserIdentityService {
  static const defaultFileName = 'crtmu_user_identity_v1.json';
  static const userIdPrefix = 'local_anon_';

  final String fileName;
  final Uuid _uuid;
  final Future<Directory> Function() _documentsDirectoryProvider;

  const LocalUserIdentityService({
    this.fileName = defaultFileName,
    Uuid? uuid,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _uuid = uuid ?? const Uuid(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  Future<String> getOrCreateUserId() async {
    final file = await _identityFile();
    if (await file.exists()) {
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final userId = decoded['userId']?.toString().trim() ?? '';
          if (_isLocalAnonymousUserId(userId)) {
            return userId;
          }
        }
      } catch (error, stackTrace) {
        debugPrint('[CrtMu][Identity] restore failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final userId = '$userIdPrefix${_uuid.v4()}';
    await _writeIdentity(file, userId);
    return userId;
  }

  Future<File> _identityFile() async {
    final dir = await _documentsDirectoryProvider();
    return File('${dir.path}/$fileName');
  }

  Future<void> _writeIdentity(File file, String userId) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, dynamic>{
        'version': 1,
        'userId': userId,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  static bool _isLocalAnonymousUserId(String userId) {
    return userId.startsWith(userIdPrefix) &&
        userId.length > userIdPrefix.length;
  }
}
