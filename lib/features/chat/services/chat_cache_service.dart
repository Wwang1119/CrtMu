import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:path_provider/path_provider.dart';

class ChatCacheService {
  static const defaultFileName = 'crtmu_chat_cache_v1.json';
  static const defaultMaxCachedMessages = 300;

  final String fileName;
  final int maxCachedMessages;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Timer? _persistDebounce;

  ChatCacheService({
    this.fileName = defaultFileName,
    this.maxCachedMessages = defaultMaxCachedMessages,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  void dispose() {
    _persistDebounce?.cancel();
  }

  Future<List<Message>> restore({
    required Message Function() fallbackMessage,
  }) async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return [fallbackMessage()];
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Cache root is not a JSON object.');
      }

      final messages = decodeMessagesFromCache(decoded.cast<String, dynamic>());
      return messages.isEmpty ? [fallbackMessage()] : messages;
    } catch (error, stackTrace) {
      debugPrint('[CrtMu][Cache] restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return [fallbackMessage()];
    }
  }

  void schedulePersist(List<Message> messages) {
    final snapshot = List<Message>.of(messages);
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        await persist(snapshot);
      } catch (error, stackTrace) {
        debugPrint('[CrtMu][Cache] persist failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  Future<void> persist(List<Message> messages) async {
    final payload = buildCachePayload(
      messages,
      maxCachedMessages: maxCachedMessages,
    );
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(payload));
  }

  Future<File> _cacheFile() async {
    final dir = await _documentsDirectoryProvider();
    return File('${dir.path}/$fileName');
  }

  static Map<String, dynamic> buildCachePayload(
    List<Message> messages, {
    int maxCachedMessages = defaultMaxCachedMessages,
    DateTime? savedAt,
  }) {
    final durable = messages.where((m) => !isTransientMessage(m)).toList();
    final start = durable.length > maxCachedMessages
        ? durable.length - maxCachedMessages
        : 0;
    final sliced = durable.sublist(start);

    return <String, dynamic>{
      'version': 1,
      'saved_at': (savedAt ?? DateTime.now()).toIso8601String(),
      'messages': sliced.map((m) => m.toJson()).toList(),
    };
  }

  static List<Message> decodeMessagesFromCache(Map<String, dynamic> root) {
    final messages = <Message>[];
    final messagesJson = root['messages'];
    if (messagesJson is! List) return messages;

    for (final item in messagesJson) {
      if (item is! Map) continue;
      try {
        final message = Message.fromJson(item.cast<String, dynamic>());
        if (isTransientMessage(message)) continue;
        messages.add(message);
      } catch (_) {
        // Best-effort restore: skip broken items instead of losing the cache.
      }
    }

    return messages;
  }

  static bool isTransientMessage(Message message) {
    return message is CustomMessage && message.metadata?['type'] == 'typing';
  }
}
