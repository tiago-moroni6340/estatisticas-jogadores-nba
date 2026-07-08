// models/player.dart

class Player {
  final int id;
  final String nome;
  final String? time; 
  final String? posicao;
  final String? fotoUrl;
  final Map<String, dynamic> raw; 

  Player({
    required this.id,
    required this.nome,
    this.time,
    this.posicao,
    this.fotoUrl,
    required this.raw,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    final id = json['nba_player_id'] ?? json['id'] ?? 0;
    final nome = json['nome_completo'] ?? json['nome'] ?? 'Jogador desconhecido';
    final time = json['time_atual'] ?? json['team'] ?? json['time'];
    final posicao = json['posicao'] ?? json['position'];
    final foto = json['foto_url'] ?? json['foto'];

    return Player(
      id: id is int ? id : int.tryParse(id.toString()) ?? 0,
      nome: nome.toString(),
      time: time?.toString(),
      posicao: posicao?.toString(),
      fotoUrl: foto?.toString(),
      raw: json,
    );
  }

  // URL corrigida com os parâmetros de dimensão
  String get fotoOficialNba {
    if (fotoUrl != null) return fotoUrl!;
    
    // Substitua pelo endereço da sua API (ex: localhost:8000 em dev ou sua URL de produção)
    // O seu próprio backend vai servir a imagem sem problemas de CORS para o navegador
    return 'http://localhost:8000/nba_dados/player_stats/player_image/$id';
  }

}