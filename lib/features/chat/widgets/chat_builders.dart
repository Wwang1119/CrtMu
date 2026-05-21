import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import 'typing_indicator.dart';

Widget buildChatComposer(BuildContext context, ChatTheme chatTheme) {
  return Composer(
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

Widget buildChatMessageFrame(
  BuildContext context,
  Message message,
  int index,
  Animation<double> animation,
  Widget child, {
  required String teacherUserId,
  bool? isRemoved,
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
}) {
  final shouldShowAvatar = groupStatus?.isLast ?? true;

  Widget avatarOrSpacer(UserID userId) {
    if (!shouldShowAvatar) return const SizedBox(width: 36);

    if (userId == teacherUserId) {
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
            child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
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

Widget buildTextMessage(
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
    sentBackgroundColor: chatTheme.colors.primary.withValues(alpha: 0.88),
    receivedBackgroundColor: chatTheme.colors.surfaceContainerHigh.withValues(
      alpha: 0.80,
    ),
    sentTextStyle: chatTheme.typography.bodyMedium.copyWith(
      color: chatTheme.colors.onPrimary,
    ),
    receivedTextStyle: chatTheme.typography.bodyMedium.copyWith(
      color: chatTheme.colors.onSurface,
    ),
  );
}

Widget buildImageMessage(
  BuildContext context,
  ImageMessage message,
  int index, {
  required ChatTheme chatTheme,
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
}) {
  final maxWidth = MediaQuery.sizeOf(context).width * 0.64;
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

Widget buildCustomMessage(
  BuildContext context,
  CustomMessage message,
  int index, {
  required ChatTheme chatTheme,
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
}) {
  final type = message.metadata?['type'];
  if (type != 'typing') return const SizedBox.shrink();

  final maxWidth = MediaQuery.sizeOf(context).width * 0.48;
  return ClipRRect(
    borderRadius: _bubbleBorderRadius(chatTheme, isSentByMe, groupStatus),
    child: Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: chatTheme.colors.surfaceContainerHigh.withValues(alpha: 0.80),
      child: const TypingIndicator(),
    ),
  );
}

Widget buildEmptyChatState(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

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
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.all(Radius.circular(22)),
            ),
            child: Icon(
              Icons.palette_outlined,
              size: 34,
              color: colorScheme.primary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '开始对话',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发一段文字，或点左侧“+”发送作品照片。\n我会按「构图 / 造型 / 色彩 / 光影」给你反馈。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: colorScheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
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

BorderRadiusGeometry _bubbleBorderRadius(
  ChatTheme theme,
  bool isSentByMe,
  MessageGroupStatus? groupStatus,
) {
  final base =
      (theme.shape as BorderRadius?) ??
      const BorderRadius.all(Radius.circular(18));

  final isGrouped = groupStatus?.isLast == false;
  final tailRadius = Radius.circular(isGrouped ? 18 : 6);
  const normalRadius = Radius.circular(18);

  if (isSentByMe) {
    return base.copyWith(bottomRight: tailRadius, bottomLeft: normalRadius);
  }

  return base.copyWith(bottomLeft: tailRadius, bottomRight: normalRadius);
}
