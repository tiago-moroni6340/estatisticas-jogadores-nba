import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../services/nba_service.dart';
import '../services/api_client.dart';

/// Carrega a lista de jogadores uma única vez e compartilha entre as telas
/// de Jogadores, Times (agrupamento) e Favoritos (filtro pelos IDs salvos).
class PlayersProvider extends ChangeNotifier {
  final _service = NbaService();

  List<Player> _jogadores = [];
  bool carregando = false;
  String? erro;

  List<Player> get jogadores => _jogadores;

  Future<void> carregar({bool forcar = false}) async {
    if (_jogadores.isNotEmpty && !forcar) return;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      _jogadores = await _service.listarJogadores();
    } on ApiException catch (e) {
      erro = e.message;
    } catch (e) {
      erro = 'Falha ao carregar jogadores. Verifique sua conexão e a URL da API.';
    }
    carregando = false;
    notifyListeners();
  }

  /// Agrupa os jogadores já carregados pela sigla/nome do time.
  Map<String, List<Player>> get jogadoresPorTime {
    final mapa = <String, List<Player>>{};
    for (final j in _jogadores) {
      final chave = (j.time ?? 'Sem time').toString();
      mapa.putIfAbsent(chave, () => []).add(j);
    }
    return mapa;
  }
}
