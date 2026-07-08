import '../models/player.dart';
import 'api_client.dart';


class NbaService {
  final _api = ApiClient.instance;

  
  Future<dynamic> statusApi() => _api.get('/nba_dados/', auth: false);

  
  Future<List<Player>> listarJogadores() async {
 
  final response = await _api.get('/nba_dados/perfil_jogadores');

  
  if (response is Map && response.containsKey('players_personal_data')) {
    final listaJson = response['players_personal_data'] as List;
    return listaJson.map((json) => Player.fromJson(json)).toList();
  } 
  
  
  if (response is List) {
    return response.map((json) => Player.fromJson(json)).toList();
  }

  return [];
}

  
  Future<Map<String, dynamic>> perfilJogador(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/perfil_jogadores/$nbaPlayerId');
    return Map<String, dynamic>.from(resp ?? {});
  }


  Future<Map<String, dynamic>> estatisticaCarreiraRegularSeason(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/player_stats/career_regular_season/$nbaPlayerId');
    if (resp is Map && resp.containsKey('player_stats_regular_season')) {
      return Map<String, dynamic>.from(resp['player_stats_regular_season'] ?? {});
    }
    return Map<String, dynamic>.from(resp ?? {});
  }

  
  Future<Map<String, dynamic>> estatisticaCarreiraPlayoffs(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/player_stats/career_playoffs/$nbaPlayerId');
    if (resp is Map && resp.containsKey('player_stats_playoffs')) {
      return Map<String, dynamic>.from(resp['player_stats_playoffs'] ?? {});
    }
    return Map<String, dynamic>.from(resp ?? {});
  }

  
  Future<Map<String, dynamic>> estatisticaCarreiraTotal(int nbaPlayerId) async {
    final resp = await _api.get('/nba_dados/player_stats/career_total/$nbaPlayerId');
    if (resp is Map && resp.containsKey('player_stats_total')) {
      return Map<String, dynamic>.from(resp['player_stats_total'] ?? {});
    }
    return Map<String, dynamic>.from(resp ?? {});
  }

  
  Future<Map<String, dynamic>> estatisticaRegularSeason(int nbaPlayerId, String season) async {
    final resp = await _api.get('/nba_dados/player_stats/regular_season/$nbaPlayerId/$season');
    if (resp is Map && resp.containsKey('player_season_stats_regular_season')) {
      final lista = resp['player_season_stats_regular_season'] as List;
      if (lista.isNotEmpty) return Map<String, dynamic>.from(lista.first);
    }
    return {};
  }

  
  Future<Map<String, dynamic>> estatisticaPlayoffs(int nbaPlayerId, String season) async {
    final resp = await _api.get('/nba_dados/player_stats/playoffs/$nbaPlayerId/$season');
    if (resp is Map && resp.containsKey('player_season_stats_playoff')) {
      final lista = resp['player_season_stats_playoff'] as List;
      if (lista.isNotEmpty) return Map<String, dynamic>.from(lista.first);
    }
    return {};
  }


  
  Future<List<dynamic>> ranking({
    required String season,
    required String etapa, 
    required String tipoEstatistica, 
    int limit = 10,
  }) async {
    final resp = await _api.get('/nba_dados/player_stats/ranking', query: {
      'season': season,
      'etapa': etapa,
      'tipo_estatistica': tipoEstatistica,
      'limit': limit,
    });

    
    if (resp is Map && resp.containsKey('ranking')) {
      return resp['ranking'] as List;
    }
    
    return _extrairLista(resp);
  }

  
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

  
  Future<List<dynamic>> jogosPorData(String dataBr) async {
    try {
     
      final partes = dataBr.split('/');
      if (partes.length != 3) throw Exception('Formato de data inválido');
      
      final dataAmericana = '${partes[1]}/${partes[0]}/${partes[2]}';

      final resp = await _api.get(
        '/nba_dados/player_stats/games',
        query: {'data': dataAmericana},
        auth: true, 
      );

      if (resp is Map && resp.containsKey('jogaways') || resp.containsKey('jogos')) {
        return resp['jogos'] as List;
      }
      return _extrairLista(resp);
    } catch (e) {
      rethrow;
    }
  }

  
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
