// widgets/player_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/favorites_provider.dart';
import '../screens/player_detail_screen.dart';
import '../theme/app_theme.dart';

class PlayerCard extends StatelessWidget {
  final Player player;
  const PlayerCard({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    // Escuta o provider de favoritos para saber se este jogador específico é favorito
    final favoritesProvider = context.watch<FavoritesProvider>();
    final isFavorito = favoritesProvider.isFavorito(player.id);

    // TRATAMENTO DO NOME: Remove espaços extras e padroniza
    final nomeTime = player.time?.trim();

    // Nova função mapeando o APELIDO do time para o slug da ESPN
    String obterSlugEspnPorNome(String? nome) {
      if (nome == null || nome.isEmpty) return '';
      
      final mapaTimes = {
        'Hawks': 'atl',
        'Celtics': 'bos',
        'Nets': 'bkn',
        'Hornets': 'cha',
        'Bulls': 'chi',
        'Cavaliers': 'cle',
        'Mavericks': 'dal',
        'Nuggets': 'den',
        'Pistons': 'det',
        'Warriors': 'gs',     // 👈 ESPN usa 'gs' para os Warriors
        'Rockets': 'hou',
        'Pacers': 'ind',
        'Clippers': 'lac',
        'Lakers': 'lal',      // 👈 ESPN usa 'lal' para os Lakers
        'Grizzlies': 'mem',
        'Heat': 'mia',
        'Bucks': 'mil',
        'Timberwolves': 'min',
        'Pelicans': 'no',
        'Knicks': 'ny',       // 👈 ESPN usa 'ny' para os Knicks
        'Thunder': 'okc',
        'Magic': 'orl',
        '76ers': 'phi',       // 👈 Mapeando o '76ers' que apareceu no seu print
        'Suns': 'phx',
        'Trail Blazers': 'por',
        'Kings': 'sac',
        'Spurs': 'sas',
        'Raptors': 'tor',
        'Jazz': 'utah',       // 👈 ESPN usa 'utah' por extenso
        'Wizards': 'was',
      };

      // Procura pelo apelido no mapa. Se não achar, tenta usar em minúsculo como fallback
      return mapaTimes[nome] ?? nome.toLowerCase();
    }

    final slugTime = obterSlugEspnPorNome(nomeTime);

    final logoTimeUrl = (slugTime.isNotEmpty && nomeTime != 'Sem time' && nomeTime != 'N/A')
        ? 'https://a.espncdn.com/i/teamlogos/nba/500/$slugTime.png'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        
        // 1. FOTO DO JOGADOR + FOTO DO TIME (LADO A LADO)
        leading: SizedBox(
          width: 65, // Espaço suficiente para sobrepor ou alinhar as duas imagens
          child: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: NetworkImage(player.fotoOficialNba),
                onBackgroundImageError: (_, __) {},
              ),
              if (logoTimeUrl != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 2),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Image.network(
                      logoTimeUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.sports_basketball, size: 14, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        title: Text(player.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Row(
          children: [
            Text(player.posicao ?? 'N/A', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(width: 6),
            const Text('•', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(width: 6),
            Text(player.time ?? 'Sem time', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
        
        // 2. A ESTRELA DE FAVORITOS NO FINAL DO CARD
        trailing: IconButton(
          icon: Icon(
            isFavorito ? Icons.star : Icons.star_border,
            color: isFavorito ? Colors.amber : AppTheme.textSecondary,
          ),
          onPressed: () {
            // Alterna o status de favorito ao clicar
            context.read<FavoritesProvider>().alternar(player.id);
          },
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerDetailScreen(player: player),
          ),
        ),
      ),
    );
  }
}