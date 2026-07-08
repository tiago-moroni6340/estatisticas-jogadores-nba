import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de favoritos. A API do `openai.yaml` não possui nenhum endpoint
/// de favoritos, então essa funcionalidade é implementada 100% no
/// dispositivo (armazenamento local com SharedPreferences), guardando os
/// IDs (`nba_player_id`) dos jogadores favoritados.
class FavoritesService {
  static const _key = 'favorite_player_ids';

  Future<Set<int>> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_key) ?? [];
    return lista.map(int.parse).toSet();
  }

  Future<void> salvar(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.map((e) => e.toString()).toList());
  }
}
