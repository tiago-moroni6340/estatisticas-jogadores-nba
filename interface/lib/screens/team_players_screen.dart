import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../widgets/player_card.dart';

class TeamPlayersScreen extends StatelessWidget {
  final Team time;
  final List<Player> jogadores;
  const TeamPlayersScreen({super.key, required this.time, required this.jogadores});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(time.nome)),
      body: jogadores.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum jogador desse time encontrado na lista carregada.\n'
                  'Isso pode acontecer se o campo de time retornado pela API '
                  'usar um formato diferente do esperado (ajuste em Player.fromJson).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: jogadores.length,
              itemBuilder: (context, i) => PlayerCard(player: jogadores[i]),
            ),
    );
  }
}
