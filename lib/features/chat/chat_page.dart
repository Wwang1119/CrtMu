import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/backend_api_client.dart';
import '../../core/network/backend_config.dart';
import '../artwork/models/artwork_models.dart';
import '../artwork/services/artwork_critique_formatter.dart';
import 'chat_constants.dart';
import 'services/chat_cache_service.dart';
import 'utils/chat_text_utils.dart';
import 'widgets/chat_builders.dart';
import 'widgets/chat_title.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _uuid = const Uuid();
  final _picker = ImagePicker();
  final _cacheService = ChatCacheService();
  late final BackendApiClient _apiClient = BackendApiClient(
    baseUrl: resolveBackendBaseUrl(),
  );

  late final InMemoryChatController _chatController;
  bool _cacheReady = false;

  late final Map<String, User> _users = {
    meUserId: const User(id: meUserId, name: '我'),
    teacherUserId: const User(id: teacherUserId, name: 'CrtMu'),
  };

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController(messages: [_openingMessage()]);
    unawaited(_restoreChatCache());
  }

  @override
  void dispose() {
    _cacheService.dispose();
    _chatController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final chatTheme = ChatTheme.fromThemeData(materialTheme).merge(
      const ChatTheme(
        colors: ChatColors(
          primary: Color(0xFF2B2F36),
          onPrimary: Colors.white,
          surface: Color(0xFF0B0F14),
          onSurface: Color(0xFFE5E7EB),
          surfaceContainerLow: Color(0xFF0F141B),
          surfaceContainer: Color(0xFF141A22),
          surfaceContainerHigh: Color(0xFF1A202A),
        ),
        typography: ChatTypography(
          bodyLarge: TextStyle(fontSize: 16, height: 1.25),
          bodyMedium: TextStyle(fontSize: 15, height: 1.25),
          bodySmall: TextStyle(fontSize: 12, height: 1.25),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        shape: BorderRadius.all(Radius.circular(18)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const CrtMuChatTitle()),
      body: Chat(
        currentUserId: meUserId,
        resolveUser: (id) async => _users[id],
        chatController: _chatController,
        theme: chatTheme,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Color(0xB3000000), BlendMode.srcOver),
          ),
        ),
        onMessageSend: _handleSendText,
        onAttachmentTap: _handlePickImage,
        builders: Builders(
          composerBuilder: (ctx) => buildChatComposer(ctx, chatTheme),
          chatMessageBuilder:
              (
                ctx,
                message,
                index,
                animation,
                child, {
                isRemoved,
                required isSentByMe,
                groupStatus,
              }) => buildChatMessageFrame(
                ctx,
                message,
                index,
                animation,
                child,
                teacherUserId: teacherUserId,
                isRemoved: isRemoved,
                isSentByMe: isSentByMe,
                groupStatus: groupStatus,
              ),
          emptyChatListBuilder: buildEmptyChatState,
          textMessageBuilder:
              (ctx, message, index, {required isSentByMe, groupStatus}) =>
                  buildTextMessage(
                    ctx,
                    message,
                    index,
                    chatTheme: chatTheme,
                    isSentByMe: isSentByMe,
                    groupStatus: groupStatus,
                  ),
          imageMessageBuilder:
              (ctx, message, index, {required isSentByMe, groupStatus}) =>
                  buildImageMessage(
                    ctx,
                    message,
                    index,
                    chatTheme: chatTheme,
                    isSentByMe: isSentByMe,
                    groupStatus: groupStatus,
                  ),
          customMessageBuilder:
              (ctx, message, index, {required isSentByMe, groupStatus}) =>
                  buildCustomMessage(
                    ctx,
                    message,
                    index,
                    chatTheme: chatTheme,
                    isSentByMe: isSentByMe,
                    groupStatus: groupStatus,
                  ),
        ),
      ),
    );
  }

  Message _openingMessage() {
    return Message.text(
      id: _uuid.v4(),
      authorId: teacherUserId,
      createdAt: DateTime.now(),
      text:
          '嗨，你好！我是 CrtMu，是世界一流的美术助教。\n'
          '我会关注到每一位学生，也会让每一位美术老师都能更快乐、更轻松地教学。\n\n'
          "Hello! I'm CrtMu, a world-class art teaching assistant. "
          'I will pay attention to every student and ensure that every art teacher '
          'can teach more happily and easily.',
    );
  }

  Future<void> _restoreChatCache() async {
    final messages = await _cacheService.restore(
      fallbackMessage: _openingMessage,
    );
    if (!mounted) return;

    await _chatController.setMessages(messages, animated: false);
    _cacheReady = true;
    _schedulePersistChatCache();
  }

  Future<void> _insertMessage(Message message) async {
    await _chatController.insertMessage(message);
    if (_cacheReady) _schedulePersistChatCache();
  }

  Future<void> _removeMessage(Message message) async {
    await _chatController.removeMessage(message);
    if (_cacheReady) _schedulePersistChatCache();
  }

  void _schedulePersistChatCache() {
    _cacheService.schedulePersist(_chatController.messages);
  }

  Future<void> _handlePickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    await _insertMessage(
      Message.image(
        id: _uuid.v4(),
        authorId: meUserId,
        createdAt: DateTime.now(),
        source: file.path,
      ),
    );

    final typingPlaceholder = _typingPlaceholder();
    await _insertMessage(typingPlaceholder);

    try {
      final upload = await _apiClient.uploadImage(
        filePath: file.path,
        userId: meUserId,
      );
      final result = await _apiClient.analyzeArtwork(
        uploadId: upload.id,
        userId: meUserId,
        studentName: '我',
        title: file.name,
      );

      await _removeMessage(typingPlaceholder);
      await _insertMessage(
        Message.text(
          id: _uuid.v4(),
          authorId: teacherUserId,
          createdAt: DateTime.now(),
          text: formatArtworkCritiqueMessage(result),
        ),
      );

      await _continueReferenceGenerationIfAvailable(result.artwork);
    } catch (error, stackTrace) {
      debugPrint('[CrtMu][Backend] image flow failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _removeTypingPlaceholderBestEffort(typingPlaceholder);
      _showError(error);
    }
  }

  Future<void> _handleSendText(String text) async {
    await _insertMessage(
      Message.text(
        id: _uuid.v4(),
        authorId: meUserId,
        createdAt: DateTime.now(),
        text: text,
        metadata: <String, dynamic>{'isOnlyEmoji': isOnlyEmoji(text)},
      ),
    );

    final typingPlaceholder = _typingPlaceholder();
    await _insertMessage(typingPlaceholder);

    try {
      final reply = await _apiClient.sendText(text);

      await _removeMessage(typingPlaceholder);
      await _insertMessage(
        Message.text(
          id: _uuid.v4(),
          authorId: teacherUserId,
          createdAt: DateTime.now(),
          text: reply,
          metadata: <String, dynamic>{'isOnlyEmoji': isOnlyEmoji(reply)},
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[CrtMu][Backend] text flow failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _removeTypingPlaceholderBestEffort(typingPlaceholder);
      _showError(error);
    }
  }

  Message _typingPlaceholder() {
    return Message.custom(
      id: _uuid.v4(),
      authorId: teacherUserId,
      createdAt: DateTime.now(),
      metadata: const <String, dynamic>{'type': 'typing'},
    );
  }

  Future<void> _continueReferenceGenerationIfAvailable(
    AnalyzedArtwork artwork,
  ) async {
    if (artwork.generationStatus == 'locked') {
      await _insertMessage(
        Message.text(
          id: _uuid.v4(),
          authorId: teacherUserId,
          createdAt: DateTime.now(),
          text:
              '这次作品已经收进成长档案。\n'
              '当前账号是免费版，会员开通后可以继续生成“优化方向参考图”。',
        ),
      );
      return;
    }

    if (artwork.generationStatus != 'ready') return;

    await _insertMessage(
      Message.text(
        id: _uuid.v4(),
        authorId: teacherUserId,
        createdAt: DateTime.now(),
        text:
            '这次作品已经收进成长档案。\n'
            '正在继续生成“优化方向参考图”…',
      ),
    );

    final generation = await _apiClient.generateReferenceImage(
      artworkId: artwork.id,
    );

    await _insertMessage(
      Message.image(
        id: _uuid.v4(),
        authorId: teacherUserId,
        createdAt: DateTime.now(),
        source: generation.imageUrl,
      ),
    );

    await _insertMessage(
      Message.text(
        id: _uuid.v4(),
        authorId: teacherUserId,
        createdAt: DateTime.now(),
        text: generation.note,
      ),
    );
  }

  Future<void> _removeTypingPlaceholderBestEffort(Message message) async {
    try {
      await _removeMessage(message);
    } catch (_) {
      // Best effort cleanup.
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(error.toString()),
      ),
    );
  }
}
