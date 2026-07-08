import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/players_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/player_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayersProvider>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = context.watch<FavoritesProvider>();
    final players = context.watch<PlayersProvider>();
    final jogadoresFavoritos =
        players.jogadores.where((j) => favoritos.isFavorito(j.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: jogadoresFavoritos.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_border, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'Você ainda não favoritou nenhum jogador.\n'
                      'Toque na estrela ao lado de um jogador para adicioná-lo aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: jogadoresFavoritos.length,
              itemBuilder: (context, i) => PlayerCard(player: jogadoresFavoritos[i]),
            ),
    );
  }
}
