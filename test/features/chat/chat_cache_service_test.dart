import 'package:art_assistant/features/chat/services/chat_cache_service.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatCacheService', () {
    test('builds payload without transient typing messages', () {
      final durable = Message.text(
        id: 'message-1',
        authorId: 'user_me',
        createdAt: DateTime.utc(2026, 1, 1),
        text: 'hello',
      );
      final typing = Message.custom(
        id: 'typing-1',
        authorId: 'bot_art_teacher',
        createdAt: DateTime.utc(2026, 1, 1),
        metadata: const {'type': 'typing'},
      );

      final payload = ChatCacheService.buildCachePayload([
        durable,
        typing,
      ], savedAt: DateTime.utc(2026, 1, 2));

      final messages = payload['messages'] as List;
      expect(messages, hasLength(1));
      expect(messages.first['id'], 'message-1');
    });

    test('keeps only the newest messages when cache is capped', () {
      final messages = List<Message>.generate(
        4,
        (index) => Message.text(
          id: 'message-$index',
          authorId: 'user_me',
          createdAt: DateTime.utc(2026, 1, index + 1),
          text: 'message $index',
        ),
      );

      final payload = ChatCacheService.buildCachePayload(
        messages,
        maxCachedMessages: 2,
        savedAt: DateTime.utc(2026, 1, 10),
      );

      final cached = payload['messages'] as List;
      expect(cached.map((item) => item['id']), ['message-2', 'message-3']);
    });

    test('decodes cached messages and skips broken items', () {
      final message = Message.text(
        id: 'message-1',
        authorId: 'user_me',
        createdAt: DateTime.utc(2026, 1, 1),
        text: 'hello',
      );
      final payload = ChatCacheService.buildCachePayload([
        message,
      ], savedAt: DateTime.utc(2026, 1, 2));
      payload['messages'] = List<dynamic>.of(payload['messages'] as List)
        ..add('not a message');

      final restored = ChatCacheService.decodeMessagesFromCache(payload);

      expect(restored, hasLength(1));
      expect(restored.single.id, 'message-1');
    });
  });
}
