import 'dart:convert';
import 'dart:io';

import 'package:art_assistant/features/user/services/local_user_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalUserIdentityService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('crtmu_identity_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    LocalUserIdentityService createService() {
      return LocalUserIdentityService(
        documentsDirectoryProvider: () async => tempDir,
      );
    }

    test('creates and restores a stable local anonymous user id', () async {
      final firstService = createService();
      final firstUserId = await firstService.getOrCreateUserId();

      final secondService = createService();
      final secondUserId = await secondService.getOrCreateUserId();

      expect(firstUserId, startsWith(LocalUserIdentityService.userIdPrefix));
      expect(secondUserId, firstUserId);
    });

    test('replaces an invalid identity file', () async {
      final file = File(
        '${tempDir.path}/${LocalUserIdentityService.defaultFileName}',
      );
      await file.writeAsString(
        jsonEncode(<String, dynamic>{'userId': 'user_me'}),
      );

      final userId = await createService().getOrCreateUserId();

      expect(userId, startsWith(LocalUserIdentityService.userIdPrefix));
      expect(userId, isNot('user_me'));
    });
  });
}
