import 'package:flutter/material.dart';

import 'features/chat/chat_page.dart';

class ArtAssistantApp extends StatelessWidget {
  const ArtAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF10B981);
    const background = Color(0xFF0B0F14);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: background,
        ).copyWith(
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
