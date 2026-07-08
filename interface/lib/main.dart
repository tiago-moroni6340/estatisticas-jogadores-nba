import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/players_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const NbaApp());
}

class NbaApp extends StatelessWidget {
  const NbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => PlayersProvider()),
      ],
      child: MaterialApp(
        title: 'NBA Stats',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const _Porteiro(),
      ),
    );
  }
}

class _Porteiro extends StatelessWidget {
  const _Porteiro();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.logado ? const HomeScreen() : const LoginScreen();
  }
}
