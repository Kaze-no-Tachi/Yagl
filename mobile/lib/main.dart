import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_screen.dart';
import 'features/library/library_screen.dart';
import 'state/providers.dart';

void main() {
  runApp(const ProviderScope(child: YaglApp()));
}

class YaglApp extends StatelessWidget {
  const YaglApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF6750A4);
    return MaterialApp(
      title: 'Yagl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Routes to the library when authenticated, otherwise the login screen.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const LoginScreen(),
      data: (loggedIn) => loggedIn ? const LibraryScreen() : const LoginScreen(),
    );
  }
}
