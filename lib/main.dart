import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 入口：当前阶段开始接入“自己的后端”。
///
/// 主链路会逐步演进成：
/// Flutter -> Node backend -> 未来的模型服务
///
/// 这样做的核心价值是：
/// 1. 不把模型密钥暴露在客户端
/// 2. 统一处理日志、超时、上传和未来的会员逻辑
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 深色系：状态栏/导航栏图标用亮色，更贴近聊天产品的“沉浸式”体验。
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ArtAssistantApp());
}

class ArtAssistantApp extends StatelessWidget {
  const ArtAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 深色系：整体黑底 + 少量强调色（用于在线状态/小点缀）。
    const accent = Color(0xFF10B981);
    const background = Color(0xFF0B0F14);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: background,
        ).copyWith(
          // 统一把背景压到更“纯黑”的氛围。
          surface: background,
          surfaceContainerHighest: const Color(0xFF141922),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrtMu',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const ChatPage(),
    );
  }
}

/// 聊天页：用 `flutter_chat_ui` + `flutter_chat_core` 的 Controller 做消息流。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _uuid = const Uuid();
  final _picker = ImagePicker();
  final _http = http.Client();

  // 当前登录用户（你）。
  static const _meId = 'user_me';

  // “AI 美术老师”的用户 ID（后续接入 Coze 真实回复时就用它发消息）。
  static const _teacherId = 'bot_art_teacher';

  // ==============================
  // Local cache (persistent chat history)
  // ==============================
  static const _chatCacheFileName = 'crtmu_chat_cache_v1.json';
  static const int _maxCachedMessages = 300;
  static const Duration _backendRequestTimeout = Duration(seconds: 20);

  Timer? _persistDebounce;
  bool _cacheReady = false;

  // ==============================
  // Coze (扣子) Open API V3
  // ==============================
  static const _cozeBaseUrl = 'https://api.coze.cn';
  static const _cozeBotId = '7528399586764275764';
  static const _cozeUserId = _meId; // 用于会话隔离（建议替换成设备ID/账号ID）

  /// 网络超时（单次请求）。
  /// 图片上传/识别比纯文本更慢，因此统一提高到 60s，避免弱网/大图导致误判失败。
  static const Duration _cozeRequestTimeout = Duration(seconds: 60);

  /// Chat 轮询总超时（整次对话，从创建 chat 到 completed）。
  /// 视觉理解通常更慢，因此这里给更充足的上限；到期会抛出 TimeoutException 并停止 loading。
  static const Duration _cozeChatTotalTimeout = Duration(minutes: 4);

  /// 轮询间隔（retrieve_chat）。
  static const Duration _cozePollInterval = Duration(seconds: 1);

  /// Coze 会话 ID：保存在内存中，实现“多轮对话”上下文；杀后台清空无所谓。
  String? _cozeConversationId;

  late final InMemoryChatController _chatController;

  // 简单的用户表：Chat 通过 resolveUser 去渲染头像/姓名。
  late final Map<String, User> _users = {
    _meId: const User(id: _meId, name: '我'),
    _teacherId: const User(id: _teacherId, name: 'CrtMu'),
  };

  @override
  void initState() {
    super.initState();

    // 先创建 Controller，再异步恢复缓存（避免 initState 做同步 IO）。
    // 默认先展示开场白，避免冷启动出现短暂“空列表/空状态”的闪烁。
    _chatController = InMemoryChatController(messages: [_openingMessage()]);
    unawaited(_restoreChatCache());
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _chatController.dispose();
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);

    // 给 Chat 单独一套更贴近聊天产品的颜色（深色系）。
    final chatTheme = ChatTheme.fromThemeData(materialTheme).merge(
      const ChatTheme(
        colors: ChatColors(
          // primary 在本项目里主要作为“我方气泡”底色使用。
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
        // 气泡圆角（默认已不错，这里稍微更圆润一点）。
        shape: BorderRadius.all(Radius.circular(18)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const _Title()),
      body: Chat(
        currentUserId: _meId,
        resolveUser: (id) async => _users[id],
        chatController: _chatController,
        theme: chatTheme,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg.png'),
            fit: BoxFit.cover,
            // 深色滤镜：压暗背景，保证对话内容对比度稳定（类似你截图里的效果）。
            colorFilter: ColorFilter.mode(Color(0xB3000000), BlendMode.srcOver),
          ),
        ),
        // 发送文本：先把“我”的气泡插入消息流（目前不请求网络）。
        onMessageSend: _handleSendText,
        // 左侧“+”：选择相册图片后直接插入图片消息。
        onAttachmentTap: _handlePickImage,
        builders: Builders(
          composerBuilder: (ctx) => _buildComposer(ctx, chatTheme),
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
              }) => _buildChatMessage(
                ctx,
                message,
                index,
                animation,
                child,
                isRemoved: isRemoved,
                isSentByMe: isSentByMe,
                groupStatus: groupStatus,
              ),
          emptyChatListBuilder: _buildEmptyState,
          textMessageBuilder:
              (ctx, message, index, {required isSentByMe, groupStatus}) =>
                  _buildTextMessage(
                    ctx,
                    message,
                    index,
                    chatTheme: chatTheme,
                    isSentByMe: isSentByMe,
                    groupStatus: groupStatus,
                  ),
          imageMessageBuilder:
              (ctx, message, index, {required isSentByMe, groupStatus}) =>
                  _buildImageMessage(
                    ctx,
                    message,
                    index,
                    chatTheme: chatTheme,
                    isSentByMe: isSentByMe,
                    groupStatus: groupStatus,
                  ),
          customMessageBuilder:
              (ctx, message, index, {required isSentByMe, groupStatus}) =>
                  _buildCustomMessage(
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

  // ==============================
  // Actions
  // ==============================

  /// 机器人开场白（首次进入 / 无缓存时展示）。
  Message _openingMessage() {
    return Message.text(
      id: _uuid.v4(),
      authorId: _teacherId,
      createdAt: DateTime.now(),
      text:
          '嗨，你好！我是 CrtMu，是世界一流的美术助教。\n'
          '我会关注到每一位学生，也会让每一位美术老师都能更快乐、更轻松地教学。\n\n'
          "Hello! I'm CrtMu, a world-class art teaching assistant. "
          'I will pay attention to every student and ensure that every art teacher '
          'can teach more happily and easily.',
    );
  }

  Future<void> _insertMessage(Message message) async {
    await _chatController.insertMessage(message);
    if (_cacheReady) _schedulePersistChatCache();
  }

  Future<void> _removeMessage(Message message) async {
    await _chatController.removeMessage(message);
    if (_cacheReady) _schedulePersistChatCache();
  }

  Future<void> _handlePickImage() async {
    // 注意：iOS/Android 需要配置权限（Info.plist/AndroidManifest.xml）。
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    // 1) 先把图片以“我”的气泡插入本地消息流（让用户立刻看到预览）。
    await _insertMessage(
      Message.image(
        id: _uuid.v4(),
        authorId: _meId,
        createdAt: DateTime.now(),
        source: file.path, // 本地文件路径
      ),
    );

    final typingPlaceholder = Message.custom(
      id: _uuid.v4(),
      authorId: _teacherId,
      createdAt: DateTime.now(),
      metadata: const <String, dynamic>{'type': 'typing'},
    );
    await _insertMessage(typingPlaceholder);

    try {
      final upload = await _uploadImageToBackend(file.path);
      final result = await _analyzeArtworkOnBackend(
        uploadId: upload.id,
        title: file.name,
      );

      await _removeMessage(typingPlaceholder);
      await _insertMessage(
        Message.text(
          id: _uuid.v4(),
          authorId: _teacherId,
          createdAt: DateTime.now(),
          text: _formatArtworkCritiqueMessage(result),
        ),
      );

      if (result.artwork.generationStatus == 'locked') {
        await _insertMessage(
          Message.text(
            id: _uuid.v4(),
            authorId: _teacherId,
            createdAt: DateTime.now(),
            text:
                '这次作品已经收进成长档案。\n'
                '当前账号是免费版，会员开通后可以继续生成“优化方向参考图”。',
          ),
        );
      } else if (result.artwork.generationStatus == 'ready') {
        await _insertMessage(
          Message.text(
            id: _uuid.v4(),
            authorId: _teacherId,
            createdAt: DateTime.now(),
            text:
                '这次作品已经收进成长档案。\n'
                '正在继续生成“优化方向参考图”…',
          ),
        );

        final generation = await _generateReferenceImageOnBackend(
          artworkId: result.artwork.id,
        );

        await _insertMessage(
          Message.image(
            id: _uuid.v4(),
            authorId: _teacherId,
            createdAt: DateTime.now(),
            source: generation.imageUrl,
          ),
        );

        await _insertMessage(
          Message.text(
            id: _uuid.v4(),
            authorId: _teacherId,
            createdAt: DateTime.now(),
            text: generation.note,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[CrtMu][Backend] image flow failed: $e');
      debugPrintStack(stackTrace: st);

      try {
        await _removeMessage(typingPlaceholder);
      } catch (_) {
        // ignore: best effort cleanup
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString()),
        ),
      );
    }
  }

  Future<void> _handleSendText(String text) async {
    // 1) 先把用户气泡插入本地消息流（保证“秒回”反馈）。
    final now = DateTime.now();
    await _insertMessage(
      Message.text(
        id: _uuid.v4(),
        authorId: _meId,
        createdAt: now,
        text: text,
        metadata: <String, dynamic>{'isOnlyEmoji': _isOnlyEmoji(text)},
      ),
    );

    // 2) 立刻插入“对方正在输入...”占位（在等待后端返回期间展示）。
    final typingPlaceholder = Message.custom(
      id: _uuid.v4(),
      authorId: _teacherId,
      createdAt: DateTime.now(),
      metadata: const <String, dynamic>{'type': 'typing'},
    );
    await _insertMessage(typingPlaceholder);

    try {
      // 3) 不再让 Flutter 直接请求模型，而是先请求自己的后端。
      // 这是更正规的产品形态：Flutter -> backend -> model provider。
      final reply = await _sendTextToBackend(text);

      // 4) 移除“正在输入”占位，插入真正的后端回复。
      await _removeMessage(typingPlaceholder);

      await _insertMessage(
        Message.text(
          id: _uuid.v4(),
          authorId: _teacherId,
          createdAt: DateTime.now(),
          text: reply,
          metadata: <String, dynamic>{'isOnlyEmoji': _isOnlyEmoji(reply)},
        ),
      );
    } catch (e, st) {
      debugPrint('[CrtMu][Backend] text flow failed: $e');
      debugPrintStack(stackTrace: st);

      try {
        await _removeMessage(typingPlaceholder);
      } catch (_) {
        // ignore: best effort cleanup
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString()),
        ),
      );
    }
  }

  String get _backendBaseUrl {
    const configured = String.fromEnvironment('BACKEND_BASE_URL');
    final trimmed = configured.trim();
    if (trimmed.isNotEmpty) {
      return _normalizeBackendBaseUrl(trimmed);
    }

    if (kReleaseMode && (Platform.isIOS || Platform.isAndroid)) {
      throw const FormatException(
        'Release build is missing BACKEND_BASE_URL. '
        'Please build with --dart-define=BACKEND_BASE_URL=https://你的后端域名',
      );
    }

    // Android 模拟器访问宿主机要走 10.0.2.2；
    // iOS 模拟器 / macOS / Windows / Linux 本地运行时可以直接用 127.0.0.1。
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://127.0.0.1:3000';
  }

  String _normalizeBackendBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('BACKEND_BASE_URL is empty.');
    }

    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Future<String> _sendTextToBackend(String text) async {
    final url = Uri.parse('$_backendBaseUrl/chat');
    final payload = <String, dynamic>{'message': text};

    debugPrint('[CrtMu][Backend] POST $url');
    debugPrint('[CrtMu][Backend] body=${jsonEncode(payload)}');

    http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_backendRequestTimeout);
    } on SocketException catch (e) {
      throw HttpException(
        'Cannot reach backend at $url.\n'
        'If you are using a real phone, run Flutter with:\n'
        '--dart-define=BACKEND_BASE_URL=http://你的电脑局域网IP:3000\n'
        '$e',
      );
    } on TimeoutException catch (e) {
      throw TimeoutException(
        'Backend request timed out after ${_backendRequestTimeout.inSeconds}s: $e',
      );
    }

    debugPrint('[CrtMu][Backend] status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] response=${response.body}');

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException(
        'Backend JSON root is not an object: ${response.body}',
      );
    }

    final root = decoded.cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend POST /chat failed: HTTP ${response.statusCode} ${response.reasonPhrase}\n'
        '${response.body}',
      );
    }

    if (root['ok'] == false) {
      throw StateError(
        root['error']?.toString() ?? 'Backend returned ok=false',
      );
    }

    final reply = root['reply']?.toString().trim() ?? '';
    if (reply.isEmpty) {
      throw FormatException('Backend response missing reply: ${response.body}');
    }

    return reply;
  }

  Future<_BackendUpload> _uploadImageToBackend(String filePath) async {
    final url = Uri.parse('$_backendBaseUrl/v1/uploads/image');
    debugPrint('[CrtMu][Backend] POST multipart $url');

    final request = http.MultipartRequest('POST', url)
      ..fields['userId'] = _meId
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(_backendRequestTimeout);
    } on SocketException catch (e) {
      throw HttpException(
        'Cannot reach backend upload endpoint at $url.\n'
        'If you are using a real phone, run Flutter with:\n'
        '--dart-define=BACKEND_BASE_URL=http://你的电脑局域网IP:3000\n'
        '$e',
      );
    } on TimeoutException catch (e) {
      throw TimeoutException(
        'Backend upload timed out after ${_backendRequestTimeout.inSeconds}s: $e',
      );
    }

    final response = await http.Response.fromStream(
      streamed,
    ).timeout(_backendRequestTimeout);

    debugPrint('[CrtMu][Backend] upload status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] upload response=${response.body}');

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException(
        'Upload JSON root is not an object: ${response.body}',
      );
    }

    final root = decoded.cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend POST /v1/uploads/image failed: HTTP ${response.statusCode} ${response.reasonPhrase}\n'
        '${response.body}',
      );
    }

    final uploadJson = root['upload'];
    if (uploadJson is! Map) {
      throw FormatException(
        'Upload response missing upload payload: ${response.body}',
      );
    }

    return _BackendUpload.fromJson(uploadJson.cast<String, dynamic>());
  }

  Future<_ArtworkAnalysisResult> _analyzeArtworkOnBackend({
    required String uploadId,
    required String title,
  }) async {
    final url = Uri.parse('$_backendBaseUrl/v1/artworks/analyze');
    final payload = <String, dynamic>{
      'userId': _meId,
      'studentName': '我',
      'title': title,
      'uploadId': uploadId,
    };

    debugPrint('[CrtMu][Backend] POST $url');
    debugPrint('[CrtMu][Backend] body=${jsonEncode(payload)}');

    http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException catch (e) {
      throw HttpException(
        'Cannot reach artwork analysis endpoint at $url.\n$e',
      );
    } on TimeoutException catch (e) {
      throw TimeoutException('Artwork analysis timed out after 60s: $e');
    }

    debugPrint('[CrtMu][Backend] analyze status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] analyze response=${response.body}');

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException(
        'Analyze JSON root is not an object: ${response.body}',
      );
    }

    final root = decoded.cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend POST /v1/artworks/analyze failed: HTTP ${response.statusCode} ${response.reasonPhrase}\n'
        '${response.body}',
      );
    }

    return _ArtworkAnalysisResult.fromJson(root);
  }

  Future<_ReferenceGenerationResult> _generateReferenceImageOnBackend({
    required String artworkId,
  }) async {
    final url = Uri.parse(
      '$_backendBaseUrl/v1/artworks/$artworkId/generate-reference',
    );

    debugPrint('[CrtMu][Backend] POST $url');

    http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 90));
    } on SocketException catch (e) {
      throw HttpException(
        'Cannot reach reference generation endpoint at $url.\n$e',
      );
    } on TimeoutException catch (e) {
      throw TimeoutException('Reference generation timed out after 90s: $e');
    }

    debugPrint('[CrtMu][Backend] generate status=${response.statusCode}');
    debugPrint('[CrtMu][Backend] generate response=${response.body}');

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException(
        'Generate JSON root is not an object: ${response.body}',
      );
    }

    final root = decoded.cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend POST /v1/artworks/$artworkId/generate-reference failed: '
        'HTTP ${response.statusCode} ${response.reasonPhrase}\n${response.body}',
      );
    }

    return _ReferenceGenerationResult.fromJson(root);
  }

  String _formatArtworkCritiqueMessage(_ArtworkAnalysisResult result) {
    final critique = result.artwork.critique;
    final buffer = StringBuffer()
      ..writeln(critique.summary)
      ..writeln()
      ..writeln('构图：${critique.scores.composition}')
      ..writeln('造型：${critique.scores.shape}')
      ..writeln('色彩：${critique.scores.color}')
      ..writeln('光影：${critique.scores.light}');

    if (critique.strengths.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('优点：${critique.strengths.join('、')}');
    }

    if (critique.weaknesses.isNotEmpty) {
      buffer.writeln('待加强：${critique.weaknesses.join('、')}');
    }

    if (critique.revisionSuggestions.isNotEmpty) {
      buffer.writeln('修改建议：');
      for (
        var index = 0;
        index < critique.revisionSuggestions.length;
        index++
      ) {
        buffer.writeln('${index + 1}. ${critique.revisionSuggestions[index]}');
      }
    }

    if (critique.nextExercise.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('下一步练习：${critique.nextExercise}');
    }

    return buffer.toString().trim();
  }

  // ==============================
  // Builders (UI customization)
  // ==============================

  Widget _buildComposer(BuildContext context, ChatTheme chatTheme) {
    // “微信感”：底部输入栏轻微磨砂 + 圆角输入框 + 左侧加号。
    return Composer(
      // 玻璃效果（轻量，不喧宾夺主）。
      sigmaX: 14,
      sigmaY: 14,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      backgroundColor: chatTheme.colors.surfaceContainerLow.withValues(
        alpha: 0.68,
      ),
      inputFillColor: chatTheme.colors.surfaceContainerHigh.withValues(
        alpha: 0.72,
      ),
      inputBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      attachmentIcon: const Icon(Icons.add_rounded, size: 26),
      hintText: '发送消息…',
      sendIcon: const Icon(Icons.arrow_upward_rounded),
      sendButtonVisibilityMode: SendButtonVisibilityMode.disabled,
      sendIconColor: chatTheme.colors.onSurface.withValues(alpha: 0.65),
      emptyFieldSendIconColor: chatTheme.colors.onSurface.withValues(
        alpha: 0.25,
      ),
    );
  }

  Widget _buildChatMessage(
    BuildContext context,
    Message message,
    int index,
    Animation<double> animation,
    Widget child, {
    bool? isRemoved,
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    // 头像：只在“最后一条”展示，减少重复元素，更高级。
    final shouldShowAvatar = groupStatus?.isLast ?? true;

    Widget avatarOrSpacer(UserID userId) {
      if (!shouldShowAvatar) return const SizedBox(width: 36);

      // AI 专属头像（资产图片）。
      if (userId == _teacherId) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: ClipOval(
              child: Image.asset(
                // 头像与 App 图标统一用同一张图（你桌面上的 icon.png）。
                'assets/images/icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Avatar(
          userId: userId,
          size: 34,
          backgroundColor: const Color(0xFF2B2F36).withValues(alpha: 0.92),
        ),
      );
    }

    return ChatMessage(
      message: message,
      index: index,
      animation: animation,
      isRemoved: isRemoved,
      groupStatus: groupStatus,
      horizontalPadding: 12,
      verticalPadding: 10,
      verticalGroupedPadding: 4,
      leadingWidget: isSentByMe
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 8),
              child: avatarOrSpacer(message.authorId),
            ),
      trailingWidget: isSentByMe
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: avatarOrSpacer(message.authorId),
            )
          : null,
      child: child,
    );
  }

  Widget _buildTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required ChatTheme chatTheme,
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    return SimpleTextMessage(
      message: message,
      index: index,
      showTime: false,
      showStatus: false,
      constraints: BoxConstraints(maxWidth: maxWidth),
      borderRadius: _bubbleBorderRadius(chatTheme, isSentByMe, groupStatus),
      // 半透明气泡，让背景图“透出来”一点（更像你截图里的沉浸式聊天）。
      sentBackgroundColor: chatTheme.colors.primary.withValues(alpha: 0.88),
      receivedBackgroundColor: chatTheme.colors.surfaceContainerHigh.withValues(
        alpha: 0.80,
      ),
      // 文字颜色：我方气泡更“微信”，对方气泡走深灰。
      sentTextStyle: chatTheme.typography.bodyMedium.copyWith(
        color: chatTheme.colors.onPrimary,
      ),
      receivedTextStyle: chatTheme.typography.bodyMedium.copyWith(
        color: chatTheme.colors.onSurface,
      ),
    );
  }

  Widget _buildImageMessage(
    BuildContext context,
    ImageMessage message,
    int index, {
    required ChatTheme chatTheme,
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.64;

    // V2：图片可能来自本地（image_picker），也可能来自 Coze（URL）。
    final source = message.source;
    final isRemote =
        source.startsWith('http://') || source.startsWith('https://');

    return ClipRRect(
      borderRadius: _bubbleBorderRadius(chatTheme, isSentByMe, groupStatus),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 360),
        decoration: BoxDecoration(
          color: chatTheme.colors.surfaceContainerHigh.withValues(alpha: 0.82),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: isRemote
            ? Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 220,
                  height: 160,
                  child: Center(child: Text('图片加载失败')),
                ),
              )
            : _buildLocalImage(source),
      ),
    );
  }

  Widget _buildLocalImage(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const SizedBox(
        width: 220,
        height: 160,
        child: Center(child: Text('图片不可用')),
      );
    }
    return Image.file(file, fit: BoxFit.cover);
  }

  Widget _buildCustomMessage(
    BuildContext context,
    CustomMessage message,
    int index, {
    required ChatTheme chatTheme,
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    final type = message.metadata?['type'];
    if (type != 'typing') return const SizedBox.shrink();

    // “对方正在输入...”占位：用更轻量的三点动画（比纯文字更像 IM 产品）。
    final maxWidth = MediaQuery.sizeOf(context).width * 0.48;
    return ClipRRect(
      borderRadius: _bubbleBorderRadius(chatTheme, isSentByMe, groupStatus),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: chatTheme.colors.surfaceContainerHigh.withValues(alpha: 0.80),
        child: const _TypingIndicator(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.all(Radius.circular(22)),
              ),
              child: Icon(
                Icons.palette_outlined,
                size: 34,
                color: cs.primary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '开始对话',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '发一段文字，或点左侧“+”发送作品照片。\n我会按「构图 / 造型 / 色彩 / 光影」给你反馈。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // Coze client (V3: create chat -> retrieve -> message list)
  // ==============================

  /// 触发一次“一来一回”的对话：
  /// - POST `/v3/chat` 发起对话（返回 chat_id / conversation_id，通常为 in_progress）
  /// - GET `/v3/chat/retrieve` 轮询直到 completed
  /// - GET `/v3/chat/message/list` 获取最终消息列表
  // ignore: unused_element
  Future<List<_CozeReply>> _cozeChatOnce(String userText) async {
    return _cozeChatOnceWithAdditionalMessages([
      <String, dynamic>{
        'role': 'user',
        'type': 'question',
        'content': userText,
        'content_type': 'text',
      },
    ]);
  }

  /// 多模态（object_string）对话：
  /// `content_type=object_string`，并且 `content` 必须是 object_string 数组序列化后的 JSON 字符串。
  // ignore: unused_element
  Future<List<_CozeReply>> _cozeChatOnceObjectString({
    required String text,
    required List<String> imageFileIds,
  }) async {
    // object_string 数组：最多 1 个 text，可以多个 image。
    final objectString = <Map<String, dynamic>>[
      <String, dynamic>{'type': 'text', 'text': text},
      for (final id in imageFileIds)
        <String, dynamic>{'type': 'image', 'file_id': id.trim()},
    ];

    return _cozeChatOnceWithAdditionalMessages([
      <String, dynamic>{
        'role': 'user',
        'type': 'question',
        'content_type': 'object_string',
        'content': jsonEncode(objectString),
      },
    ]);
  }

  Future<List<_CozeReply>> _cozeChatOnceWithAdditionalMessages(
    List<Map<String, dynamic>> additionalMessages,
  ) async {
    final authorization = _resolveCozeAuthorizationHeader();

    final url = _cozeConversationId == null
        ? Uri.parse('$_cozeBaseUrl/v3/chat')
        : Uri.parse('$_cozeBaseUrl/v3/chat').replace(
            queryParameters: <String, String>{
              'conversation_id': _cozeConversationId!,
            },
          );
    final payload = <String, dynamic>{
      'bot_id': _cozeBotId,
      'user_id': _cozeUserId,
      'stream': false,
      'auto_save_history': true,
      'additional_messages': additionalMessages,
    };

    _assertCozeCn(url);
    _debugPrintCozeRequest(
      method: 'POST',
      url: url,
      authorization: authorization,
    );
    final response = await _http
        .post(
          url,
          headers: _cozeHeaders(authorization),
          body: jsonEncode(payload),
        )
        .timeout(_cozeRequestTimeout);

    final root = _decodeJsonObject(response);

    if (response.statusCode != 200) {
      throw HttpException(
        'Coze POST /v3/chat failed: HTTP ${response.statusCode} ${response.reasonPhrase}'
        '${_formatCozeLogId(response)}\n${response.body}',
      );
    }
    _assertCozeOk(root);

    final data = (root['data'] as Map?)?.cast<String, dynamic>();
    if (data == null) {
      throw const FormatException('Coze response missing data field.');
    }

    final chatId = data['id']?.toString();
    final conversationId = data['conversation_id']?.toString();
    if (chatId == null ||
        chatId.isEmpty ||
        conversationId == null ||
        conversationId.isEmpty) {
      throw FormatException(
        'Coze response missing chat_id/conversation_id. data=$data',
      );
    }

    debugPrint(
      '[CrtMu][Coze] chat created chat_id=$chatId conversation_id=$conversationId',
    );

    // 记住 conversation_id，用于下一轮对话上下文。
    _cozeConversationId = conversationId;
    _schedulePersistChatCache();

    await _pollCozeUntilCompleted(
      authorization,
      conversationId: conversationId,
      chatId: chatId,
      totalTimeout: _cozeChatTotalTimeout,
    );

    final messages = await _fetchCozeMessages(
      authorization,
      conversationId: conversationId,
      chatId: chatId,
    );

    // 只取 “assistant + answer” 的最终结果；follow_up/verbose 等暂不展示。
    final answers = <_CozeReply>[];
    for (final m in messages) {
      final role = m['role']?.toString();
      final type = m['type']?.toString();
      final contentType = m['content_type']?.toString();
      final content = m['content']?.toString();

      if (role != 'assistant') continue;
      if (type != 'answer') continue;
      if (content == null || content.trim().isEmpty) continue;

      if (contentType == 'image') {
        answers.add(
          _CozeReply(
            _CozeContentType.image,
            _normalizeCozeImageContent(content),
          ),
        );
      } else {
        // 默认按 text 处理（content_type= text / markdown 等）。
        answers.add(_CozeReply(_CozeContentType.text, content));
      }
    }

    return answers;
  }

  /// Coze 文件上传（V1）：
  /// - POST `https://api.coze.cn/v1/files/upload`
  /// - multipart/form-data，字段名 `file`
  /// - 返回 `data.id`（即 file_id）
  // ignore: unused_element
  Future<String> _cozeUploadFile({
    required String authorization,
    required String filePath,
  }) async {
    final url = Uri.parse('$_cozeBaseUrl/v1/files/upload');

    _assertCozeCn(url);
    _debugPrintCozeRequest(
      method: 'POST',
      url: url,
      authorization: authorization,
    );
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(<String, String>{
        'Authorization': authorization,
        'Accept': 'application/json',
      })
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await _http.send(request).timeout(_cozeRequestTimeout);
    // 注意：send() 只保证拿到响应头；读取响应体也可能卡住，因此这里也加超时兜底。
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(_cozeRequestTimeout);

    final root = _decodeJsonObject(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Coze POST /v1/files/upload failed: HTTP ${response.statusCode} ${response.reasonPhrase}'
        '${_formatCozeLogId(response)}\n${response.body}',
      );
    }
    _assertCozeOk(root);

    // 兼容不同返回：优先 data.id，其次 data.file_id，最后 id。
    final data = root['data'];
    String? id;
    if (data is Map) {
      id = (data['id'] ?? data['file_id'] ?? data['fileId'])?.toString();
    }
    id ??= root['id']?.toString();

    if (id == null || id.trim().isEmpty) {
      throw FormatException(
        'Coze upload response missing file_id. body=${response.body}',
      );
    }

    debugPrint('[CrtMu][Coze] upload ok file_id=$id');
    return id;
  }

  /// 读取 `COZE_TOKEN` 并规范化为完整的 Authorization Header 值。
  ///
  /// 约定：
  /// - 允许传 `pat_xxx` / `Bearer pat_xxx` / `Authorization: Bearer pat_xxx`
  /// - 如果没有 Bearer 前缀，会自动补上
  /// - 如果是空字符串，会在控制台打印 `TOKEN IS EMPTY!` 并抛异常
  String _resolveCozeAuthorizationHeader() {
    // 强烈建议你用 `--dart-define=COZE_TOKEN=...` 注入：
    // flutter run --dart-define=COZE_TOKEN=pat_xxx
    //
    // 注意：不要把 Token 硬编码进仓库，也不要提交到 Git。
    const raw = String.fromEnvironment('COZE_TOKEN');
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      // ignore: avoid_print
      print('TOKEN IS EMPTY!');
      throw StateError(
        'Missing COZE_TOKEN. Please run with: --dart-define=COZE_TOKEN=your_pat_token',
      );
    }

    // 允许开发者误把完整 Header 值粘贴进来：`Authorization: Bearer pat_xxx`
    final authPrefix = RegExp(r'^Authorization\s*:\s*', caseSensitive: false);
    var tokenPart = trimmed.replaceFirst(authPrefix, '').trim();

    // 防御性：如果用户传了多层 Bearer（例如 `Bearer Bearer pat_xxx`），全部剥离干净。
    final bearerPrefix = RegExp(r'^Bearer\s*:?\s*', caseSensitive: false);
    while (bearerPrefix.hasMatch(tokenPart)) {
      tokenPart = tokenPart.replaceFirst(bearerPrefix, '').trim();
    }

    final token = tokenPart;

    if (token.isEmpty) {
      // ignore: avoid_print
      print('TOKEN IS EMPTY!');
      throw StateError('COZE_TOKEN is invalid: token part is empty.');
    }

    // 防御性：token 不应该包含空白字符；如果有，90% 是复制/拼接时混入了换行或空格。
    if (token.contains(RegExp(r'\s'))) {
      debugPrint(
        '[CrtMu][Coze] WARNING: COZE_TOKEN contains whitespace characters.',
      );
    }

    return 'Bearer $token';
  }

  // ==============================
  // Chat cache (local persistence)
  // ==============================

  Future<File> _chatCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_chatCacheFileName');
  }

  bool _isTransientMessage(Message message) {
    // 只做“聊天记录”缓存：输入中占位这类临时 UI 状态不落盘。
    return message is CustomMessage && message.metadata?['type'] == 'typing';
  }

  Future<void> _restoreChatCache() async {
    // 关键：启动时先读取缓存，再允许落盘；避免“先写开场白覆盖旧记录”。
    try {
      final file = await _chatCacheFile();
      if (!await file.exists()) {
        return;
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Cache root is not a JSON object.');
      }

      final root = decoded.cast<String, dynamic>();
      final conversationId = root['conversation_id']?.toString();
      if (conversationId != null && conversationId.trim().isNotEmpty) {
        _cozeConversationId = conversationId.trim();
      }

      final list = <Message>[];
      final messagesJson = root['messages'];
      if (messagesJson is List) {
        for (final item in messagesJson) {
          if (item is! Map) continue;
          try {
            final msg = Message.fromJson(item.cast<String, dynamic>());
            if (_isTransientMessage(msg)) continue;
            list.add(msg);
          } catch (_) {
            // ignore: best effort restore (skip broken item)
          }
        }
      }

      if (list.isEmpty) {
        list.add(_openingMessage());
      }

      await _chatController.setMessages(list, animated: false);
    } catch (e, st) {
      debugPrint('[CrtMu][Cache] restore failed: $e');
      debugPrintStack(stackTrace: st);
      // 兜底：保证至少有开场白，不至于白屏。
      await _chatController.setMessages([_openingMessage()], animated: false);
    } finally {
      if (mounted) {
        _cacheReady = true;
        _schedulePersistChatCache();
      }
    }
  }

  void _schedulePersistChatCache() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        await _persistChatCache();
      } catch (e, st) {
        debugPrint('[CrtMu][Cache] persist failed: $e');
        debugPrintStack(stackTrace: st);
      }
    });
  }

  Future<void> _persistChatCache() async {
    final all = _chatController.messages;
    final durable = all.where((m) => !_isTransientMessage(m)).toList();

    // 控制缓存体积：只保留最近 N 条。
    final start = durable.length > _maxCachedMessages
        ? durable.length - _maxCachedMessages
        : 0;
    final sliced = durable.sublist(start);

    final payload = <String, dynamic>{
      'version': 1,
      'saved_at': DateTime.now().toIso8601String(),
      'conversation_id': _cozeConversationId,
      'messages': sliced.map((m) => m.toJson()).toList(),
    };

    final file = await _chatCacheFile();
    await file.writeAsString(jsonEncode(payload));
  }

  Map<String, String> _cozeHeaders(String authorization) => <String, String>{
    'Authorization': authorization,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  void _assertCozeCn(Uri url) {
    // 二次确认域名：国内版必须走 api.coze.cn
    if (url.scheme != 'https' || url.host != 'api.coze.cn') {
      throw StateError(
        'Coze API base URL must be https://api.coze.cn, got: $url',
      );
    }
  }

  /// Debug 专用：打印完整请求 URL 与完整 Authorization Header。
  /// 注意：这会泄露 Token，请仅用于本地联调，确认无误后务必删除/关闭。
  void _debugPrintCozeRequest({
    required String method,
    required Uri url,
    required String authorization,
  }) {
    assert(() {
      // ignore: avoid_print
      print('[CrtMu][Coze] $method $url');
      // ignore: avoid_print
      print('[CrtMu][Coze] Authorization: $authorization');
      return true;
    }());
  }

  String _formatCozeLogId(http.Response resp) {
    // ByteDance 系列接口常见排障头：X-Tt-Logid（便于你在平台侧定位请求）。
    final logId = resp.headers['x-tt-logid'];
    if (logId == null || logId.isEmpty) return '';
    return '\nX-Tt-Logid: $logId';
  }

  Map<String, dynamic> _decodeJsonObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      throw const FormatException('Root JSON is not an object.');
    } catch (e) {
      throw FormatException('Invalid JSON from Coze: $e\n${response.body}');
    }
  }

  void _assertCozeOk(Map<String, dynamic> root) {
    // Coze 返回通常包含 code/msg 或 code/message。
    final code = root['code'];
    if (code is num && code.toInt() == 0) return;
    if (code == null) return; // 有些实现可能不带 code，先放行。

    final msg = root['msg'] ?? root['message'] ?? '';
    throw StateError('Coze error: code=$code msg=$msg');
  }

  Future<void> _pollCozeUntilCompleted(
    String authorization, {
    required String conversationId,
    required String chatId,
    required Duration totalTimeout,
  }) async {
    final url = Uri.parse('$_cozeBaseUrl/v3/chat/retrieve').replace(
      queryParameters: {'conversation_id': conversationId, 'chat_id': chatId},
    );

    _assertCozeCn(url);
    _debugPrintCozeRequest(
      method: 'GET',
      url: url,
      authorization: authorization,
    );

    final sw = Stopwatch()..start();
    String? lastStatus;
    dynamic lastError;

    var attempt = 0;
    while (sw.elapsed < totalTimeout) {
      attempt++;
      final resp = await _http
          .get(url, headers: _cozeHeaders(authorization))
          .timeout(_cozeRequestTimeout);

      final root = _decodeJsonObject(resp);
      if (resp.statusCode != 200) {
        throw HttpException(
          'Coze GET /v3/chat/retrieve failed: HTTP ${resp.statusCode} ${resp.reasonPhrase}'
          '${_formatCozeLogId(resp)}\n${resp.body}',
        );
      }
      _assertCozeOk(root);

      final data = (root['data'] as Map?)?.cast<String, dynamic>();
      final status = data?['status']?.toString();
      lastStatus = status;
      lastError = data?['last_error'];
      if (status == 'completed') return;

      if (status == 'failed' || status == 'cancelled' || status == 'canceled') {
        throw StateError('Coze chat status=$status last_error=$lastError');
      }

      // 关键：如果 Bot 触发了工具调用并要求客户端提交结果（requires_action），
      // 不处理会导致一直卡在 requires_action，看起来像“永远在输入”。
      if (status == 'requires_action') {
        final requiredAction = data?['required_action'];
        throw StateError(
          'Coze chat requires_action, required_action=$requiredAction',
        );
      }

      // 控制台打印进度，方便真机联调定位“卡在哪里”。
      if (attempt == 1 || attempt % 5 == 0) {
        debugPrint(
          '[CrtMu][Coze] poll#$attempt status=$status elapsed=${sw.elapsed.inSeconds}s',
        );
      }

      await Future.delayed(_cozePollInterval);
    }

    throw TimeoutException(
      'Coze chat timed out after ${totalTimeout.inSeconds}s '
      '(last_status=$lastStatus last_error=$lastError)',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCozeMessages(
    String authorization, {
    required String conversationId,
    required String chatId,
  }) async {
    final url = Uri.parse('$_cozeBaseUrl/v3/chat/message/list').replace(
      queryParameters: {'conversation_id': conversationId, 'chat_id': chatId},
    );

    _assertCozeCn(url);
    _debugPrintCozeRequest(
      method: 'GET',
      url: url,
      authorization: authorization,
    );

    final resp = await _http
        .get(url, headers: _cozeHeaders(authorization))
        .timeout(_cozeRequestTimeout);

    final root = _decodeJsonObject(resp);
    if (resp.statusCode != 200) {
      throw HttpException(
        'Coze GET /v3/chat/message/list failed: HTTP ${resp.statusCode} ${resp.reasonPhrase}'
        '${_formatCozeLogId(resp)}\n${resp.body}',
      );
    }
    _assertCozeOk(root);

    final data = root['data'];
    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      debugPrint('[CrtMu][Coze] message/list count=${list.length}');
      return list;
    }

    throw FormatException(
      'Unexpected Coze message/list data shape: ${data.runtimeType}',
    );
  }

  /// 兼容部分返回：图片 content 可能是 URL，也可能是 JSON 字符串（含 url 字段）。
  String _normalizeCozeImageContent(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // 尝试解析 JSON：{"url":"..."} 或 {"image_url":"..."} 等。
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final url =
            decoded['url'] ?? decoded['image_url'] ?? decoded['imageUrl'];
        if (url != null) return url.toString();
      }
    } catch (_) {
      // ignore: fallback below
    }

    return trimmed;
  }

  // ==============================
  // Helpers
  // ==============================

  /// 气泡圆角做一点“微信式”的方向感（左右两侧略有差异）。
  BorderRadiusGeometry _bubbleBorderRadius(
    ChatTheme theme,
    bool isSentByMe,
    MessageGroupStatus? groupStatus,
  ) {
    final base =
        (theme.shape as BorderRadius?) ??
        const BorderRadius.all(Radius.circular(18));

    // 如果是分组中间/非末尾，底部更圆润，视觉上更“连贯”。
    final isGrouped = (groupStatus?.isLast == false);

    final tailRadius = Radius.circular(isGrouped ? 18 : 6);
    final normalRadius = const Radius.circular(18);

    if (isSentByMe) {
      return base.copyWith(bottomRight: tailRadius, bottomLeft: normalRadius);
    }

    return base.copyWith(bottomLeft: tailRadius, bottomRight: normalRadius);
  }

  /// 简易判断“仅表情”——用于放大 emoji（flutter_chat_ui 内置逻辑用 metadata）。
  bool _isOnlyEmoji(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // 非严格实现：覆盖常见 emoji 区间，够用且轻量。
    final emoji = RegExp(
      r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}\s]+$',
      unicode: true,
    );
    return emoji.hasMatch(trimmed);
  }
}

enum _CozeContentType { text, image }

class _CozeReply {
  final _CozeContentType contentType;
  final String content;

  const _CozeReply(this.contentType, this.content);
}

class _BackendUpload {
  final String id;
  final String localUrl;

  const _BackendUpload({required this.id, required this.localUrl});

  factory _BackendUpload.fromJson(Map<String, dynamic> json) {
    return _BackendUpload(
      id: json['id']?.toString() ?? '',
      localUrl: json['localUrl']?.toString() ?? '',
    );
  }
}

class _ArtworkAnalysisResult {
  final _AnalyzedArtwork artwork;

  const _ArtworkAnalysisResult({required this.artwork});

  factory _ArtworkAnalysisResult.fromJson(Map<String, dynamic> json) {
    final artworkJson = json['artwork'];
    if (artworkJson is! Map) {
      throw const FormatException('Artwork analysis response missing artwork.');
    }

    return _ArtworkAnalysisResult(
      artwork: _AnalyzedArtwork.fromJson(artworkJson.cast<String, dynamic>()),
    );
  }
}

class _ReferenceGenerationResult {
  final String imageUrl;
  final String note;

  const _ReferenceGenerationResult({
    required this.imageUrl,
    required this.note,
  });

  factory _ReferenceGenerationResult.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'];
    if (resultJson is! Map) {
      throw const FormatException(
        'Reference generation response missing result.',
      );
    }

    return _ReferenceGenerationResult(
      imageUrl: resultJson['imageUrl']?.toString() ?? '',
      note: resultJson['note']?.toString() ?? '参考图已生成。',
    );
  }
}

class _AnalyzedArtwork {
  final String id;
  final String generationStatus;
  final _ArtworkCritique critique;

  const _AnalyzedArtwork({
    required this.id,
    required this.generationStatus,
    required this.critique,
  });

  factory _AnalyzedArtwork.fromJson(Map<String, dynamic> json) {
    final critiqueJson = json['critique'];
    final generationJson = json['generation'];
    if (critiqueJson is! Map) {
      throw const FormatException('Artwork payload missing critique.');
    }

    return _AnalyzedArtwork(
      id: json['id']?.toString() ?? '',
      generationStatus: generationJson is Map
          ? generationJson['status']?.toString() ?? ''
          : '',
      critique: _ArtworkCritique.fromJson(critiqueJson.cast<String, dynamic>()),
    );
  }
}

class _ArtworkCritique {
  final String summary;
  final _ArtworkScores scores;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> revisionSuggestions;
  final String nextExercise;

  const _ArtworkCritique({
    required this.summary,
    required this.scores,
    required this.strengths,
    required this.weaknesses,
    required this.revisionSuggestions,
    required this.nextExercise,
  });

  factory _ArtworkCritique.fromJson(Map<String, dynamic> json) {
    final scoresJson = json['scores'];
    if (scoresJson is! Map) {
      throw const FormatException('Critique payload missing scores.');
    }

    List<String> parseStringList(dynamic value) {
      if (value is! List) return const <String>[];
      return value.map((item) => item.toString()).toList();
    }

    return _ArtworkCritique(
      summary: json['summary']?.toString() ?? '',
      scores: _ArtworkScores.fromJson(scoresJson.cast<String, dynamic>()),
      strengths: parseStringList(json['strengths']),
      weaknesses: parseStringList(json['weaknesses']),
      revisionSuggestions: parseStringList(json['revisionSuggestions']),
      nextExercise: json['nextExercise']?.toString() ?? '',
    );
  }
}

class _ArtworkScores {
  final int composition;
  final int shape;
  final int color;
  final int light;

  const _ArtworkScores({
    required this.composition,
    required this.shape,
    required this.color,
    required this.light,
  });

  factory _ArtworkScores.fromJson(Map<String, dynamic> json) {
    int parseScore(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return _ArtworkScores(
      composition: parseScore(json['composition']),
      shape: parseScore(json['shape']),
      color: parseScore(json['color']),
      light: parseScore(json['light']),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CrtMu',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '随时待命',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 三点“正在输入”动画（轻量、低侵入，不依赖额外三方库）。
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = Colors.white.withValues(alpha: 0.62);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value; // 0..1
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: _phase(t, 0.0), color: dotColor),
            const SizedBox(width: 6),
            _Dot(opacity: _phase(t, 0.2), color: dotColor),
            const SizedBox(width: 6),
            _Dot(opacity: _phase(t, 0.4), color: dotColor),
            const SizedBox(width: 10),
            Text(
              'CrtMu 正在输入…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.70),
                height: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }

  double _phase(double t, double shift) {
    final x = (t + shift) % 1.0;
    // 让每个点在一段时间内更“亮”，其余更“暗”。
    final v = (1.0 - (x - 0.5).abs() * 2).clamp(0.0, 1.0);
    return 0.25 + v * 0.75;
  }
}

class _Dot extends StatelessWidget {
  final double opacity;
  final Color color;

  const _Dot({required this.opacity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
