import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/players_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/player_card.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String _busca = '';

  @override
void initState() {
  super.initState();
  // Dispara o carregamento do Provider assim que a sub-tela for montada
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<PlayersProvider>().carregar();
  });
}

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayersProvider>();
    final jogadores = provider.jogadores
        .where((j) => j.nome.toLowerCase().contains(_busca.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Jogadores')),
      body: RefreshIndicator(
        onRefresh: () => context.read<PlayersProvider>().carregar(forcar: true),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar jogador...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
            ),
            Expanded(child: _buildConteudo(provider, jogadores)),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo(PlayersProvider provider, List jogadores) {
    if (provider.carregando && provider.jogadores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.erro != null && provider.jogadores.isEmpty) {
      return _erro(provider.erro!, () => provider.carregar(forcar: true));
    }
    if (jogadores.isEmpty) {
      return const Center(
        child: Text('Nenhum jogador encontrado',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: jogadores.length,
      itemBuilder: (context, i) => PlayerCard(player: jogadores[i]),
    );
  }

  Widget _erro(String mensagem, VoidCallback onTentar) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onTentar, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
