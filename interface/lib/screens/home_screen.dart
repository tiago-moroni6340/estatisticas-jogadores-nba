import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'players_screen.dart';
import 'teams_screen.dart';
import 'favorites_screen.dart';
import 'compare_screen.dart';
import 'ranking_screen.dart';
import 'historico_games_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;
  
  final _telas = const [
    PlayersScreen(),
    CompareScreen(),
    RankingScreen(),
    HistoricoGamesScreen(),
    TeamsScreen(),
    FavoritesScreen(),
  ];

  Future<void> _sair() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _indice, children: _telas),
          Positioned(
            top: 4,
            right: 4,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sair',
                onPressed: _sair,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) => setState(() => _indice = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Jogadores'),
          BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: 'Comparar'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_outlined), label: 'Rankings'),
          
          
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Histórico'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'Times'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Favoritos'),
        ],
      ),
    );
  }
}
