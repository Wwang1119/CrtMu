bool isOnlyEmoji(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  final emoji = RegExp(
    r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}\s]+$',
    unicode: true,
  );
  return emoji.hasMatch(trimmed);
}
