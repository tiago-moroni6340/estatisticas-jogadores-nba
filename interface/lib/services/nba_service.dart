import '../models/player.dart';
import 'api_client.dart';

/// Serviço com todos os endpoints de dados da NBA descritos no `openai.yaml`.
class NbaService {
  final _api = ApiClient.instance;

  /// GET /nba_dados/  (healthcheck)
  Future<dynamic> statusApi() => _api.get('/nba_dados/', auth: false);

  /// GET /nba_dados/perfil_jogadores
  Future<List<Player>> listarJogadores() async {
  // Chamada get padrão no endpoint da API
  final response = await _api.get('/nba_dados/perfil_jogadores');

  // AJUSTADO AQUI:
  // Se a resposta for o dicionário/mapa que você nos mostrou:
  if (response is Map && response.containsKey('players_personal_data')) {
    final listaJson = response['players_personal_data'] as List;
    return listaJson.map((json) => Player.fromJson(json)).toList();
  } 
  
  // Tratamento fallback caso venha uma lista crua direto
  if (response is List) {
    return response.map((json) => Player.fromJson(json)).toList();
  }

  return [];
}

  /// GET /nba_dados/perfil_jogadores/{nba_player_id}
  Future<Map<String, dynamic>> perfilJogador(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/perfil_jogadores/$nbaPlayerId');
    return Map<String, dynamic>.from(resp ?? {});
  }

  /// GET /nba_dados/player_stats/career_regular_season/{nba_player_id}
  Future<Map<String, dynamic>> estatisticaCarreiraRegularSeason(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/player_stats/career_regular_season/$nbaPlayerId');
    if (resp is Map && resp.containsKey('player_stats_regular_season')) {
      return Map<String, dynamic>.from(resp['player_stats_regular_season'] ?? {});
    }
    return Map<String, dynamic>.from(resp ?? {});
  }

  /// GET /nba_dados/player_stats/career_playoffs/{nba_player_id}
  Future<Map<String, dynamic>> estatisticaCarreiraPlayoffs(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/player_stats/career_playoffs/$nbaPlayerId');
    if (resp is Map && resp.containsKey('player_stats_playoffs')) {
      return Map<String, dynamic>.from(resp['player_stats_playoffs'] ?? {});
    }
    return Map<String, dynamic>.from(resp ?? {});
  }

  /// GET /nba_dados/player_stats/career_total/{nba_player_id}
  Future<Map<String, dynamic>> estatisticaCarreiraTotal(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/player_stats/career_total/$nbaPlayerId');
    if (resp is Map && resp.containsKey('player_stats_total')) {
      return Map<String, dynamic>.from(resp['player_stats_total'] ?? {});
    }
    return Map<String, dynamic>.from(resp ?? {});
  }

  /// GET /nba_dados/player_stats/regular_season/{nba_player_id}/{season}
  Future<Map<String, dynamic>> estatisticaRegularSeason(int nbaPlayerId, String season) async {
    final resp = await _api.get('/nba_dados/player_stats/regular_season/$nbaPlayerId/$season');
    if (resp is Map && resp.containsKey('player_season_stats_regular_season')) {
      final lista = resp['player_season_stats_regular_season'] as List;
      if (lista.isNotEmpty) return Map<String, dynamic>.from(lista.first);
    }
    return {};
  }

  /// GET /nba_dados/player_stats/playoffs/{nba_player_id}/{season}
  Future<Map<String, dynamic>> estatisticaPlayoffs(int nbaPlayerId, String season) async {
    final resp = await _api.get('/nba_dados/player_stats/playoffs/$nbaPlayerId/$season');
    if (resp is Map && resp.containsKey('player_season_stats_playoff')) {
      final lista = resp['player_season_stats_playoff'] as List;
      if (lista.isNotEmpty) return Map<String, dynamic>.from(lista.first);
    }
    return {};
  }


  /// GET /nba_dados/player_stats/ranking
  Future<List<dynamic>> ranking({
    required String season,
    required String etapa, // 'regular' | 'playoffs' | 'all'
    required String tipoEstatistica, // 'pts' | 'ast' | 'reb' | 'min' ...
    int limit = 10,
  }) async {
    final resp = await _api.get('/nba_dados/player_stats/ranking', query: {
      'season': season,
      'etapa': etapa,
      'tipo_estatistica': tipoEstatistica,
      'limit': limit,
    });

    // Ajustado para capturar a chave exata da resposta do ranking
    if (resp is Map && resp.containsKey('ranking')) {
      return resp['ranking'] as List;
    }
    
    return _extrairLista(resp);
  }

  /// GET /nba_dados/player_stats/compare
  Future<Map<String, dynamic>> comparar({
    required int playerId1,
    required int playerId2,
    required String season,
    required String etapa,
  }) async {
    final resp = await _api.get('/nba_dados/player_stats/compare', query: {
      'player_id_1': playerId1,
      'player_id_2': playerId2,
      'season': season,
      'etapa': etapa,
    });
    return Map<String, dynamic>.from(resp ?? {});
  }

  /// GET /nba_dados/player_stats/games (não exige autenticação no yaml)
  Future<List<dynamic>> jogosPorData(String dataBr) async {
    try {
      // Converte DD/MM/AAAA para MM/DD/YYYY
      final partes = dataBr.split('/');
      if (partes.length != 3) throw Exception('Formato de data inválido');
      
      final dataAmericana = '${partes[1]}/${partes[0]}/${partes[2]}';

      final resp = await _api.get(
        '/nba_dados/player_stats/games',
        query: {'data': dataAmericana},
        auth: true, // Garante envio do Token injetado pelo ApiClient
      );

      if (resp is Map && resp.containsKey('jogaways') || resp.containsKey('jogos')) {
        return resp['jogos'] as List;
      }
      return _extrairLista(resp);
    } catch (e) {
      rethrow;
    }
  }

  /// GET /nba_dados/player_stats/timeline (não exige autenticação no yaml)
  Future<List<dynamic>> timelineJogador({
    required int playerId,
    String temporada = '2025-26',
  }) async {
    final resp = await _api.get('/nba_dados/player_stats/timeline', query: {
      'player_id': playerId,
      'temporada': temporada,
    }, auth: true);

    if (resp is Map && resp.containsKey('historico')) {
      return resp['historico'] as List;
    }
    return _extrairLista(resp);
  }

  /// Normaliza a resposta da API para sempre virar uma List, já que o yaml
  /// não define o formato exato (pode vir como lista pura ou dentro de uma
  /// chave como {"data": [...]} ou {"jogadores": [...]}).
  List<dynamic> _extrairLista(dynamic resp) {
    if (resp is List) return resp;
    if (resp is Map) {
      for (final chave in ['data', 'jogadores', 'players', 'resultado', 'results']) {
        if (resp[chave] is List) return resp[chave] as List;
      }
    }
    return [];
  }
}
