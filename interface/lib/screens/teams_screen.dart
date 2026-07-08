// screens/teams_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team.dart';
import '../providers/players_provider.dart';
import '../theme/app_theme.dart';
import 'team_players_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayersProvider>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayersProvider>();
    final agrupado = provider.jogadoresPorTime;

    return Scaffold(
      appBar: AppBar(title: const Text('Times')),
      body: provider.carregando && provider.jogadores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: Team.todos.length,
              itemBuilder: (context, i) {
                final time = Team.todos[i];
                final jogadoresDoTime = agrupado.entries
                    .where((e) =>
                        e.key.toUpperCase().contains(time.sigla) ||
                        time.nome.toLowerCase().contains(e.key.toLowerCase()))
                    .expand((e) => e.value)
                    .toList();

                // URL dinâmica para o escudo oficial transparente via ESPN CDN
                final logoTimeUrl = 'https://a.espncdn.com/i/teamlogos/nba/500/${time.sigla.toLowerCase()}.png';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        logoTimeUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback caso a imagem falhe
                          return Center(
                            child: Text(time.sigla, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                    title: Text(time.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${jogadoresDoTime.length} jogador(es) carregado(s)',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamPlayersScreen(
                          time: time,
                          jogadores: jogadoresDoTime,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}