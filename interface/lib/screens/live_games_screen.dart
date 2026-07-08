import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme/app_theme.dart';

class LiveGamesScreen extends StatefulWidget {
  const LiveGamesScreen({super.key});

  @override
  State<LiveGamesScreen> createState() => _LiveGamesScreenState();
}

class _LiveGamesScreenState extends State<LiveGamesScreen> {
  late WebSocketChannel _channel;
  List<dynamic> _jogos = [];
  bool _conectando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _conectarWebSocket();
  }

  void _conectarWebSocket() {
    try {
      // IMPORTANTE: Troque pelo IP/Porta da sua API. 
      // Se usar emulador Android, localhost é 10.0.2.2.
      // Se for Flutter Web, localhost funciona normalmente.
      final wsUrl = Uri.parse('ws://127.0.0.1:8000/ws/partidas-ao-vivo');
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel.stream.listen(
        (mensagem) {
          final dadosDecodificados = jsonDecode(mensagem);
          
          if (dadosDecodificados['tipo'] == 'atualizacao_jogos') {
            // A estrutura depende de como o seu Rust/Python envia o JSON,
            // mas assumindo que venha uma lista dentro de "dados" -> "jogos"
            setState(() {
              _jogos = dadosDecodificados['dados']['jogos'] ?? [];
              _conectando = false;
              _erro = null;
            });
          }
        },
        onError: (error) {
          setState(() {
            _erro = 'Falha na conexão em tempo real.';
            _conectando = false;
          });
        },
        onDone: () {
          // Opcional: tentar reconectar se o servidor cair
          setState(() {
            _erro = 'Conexão encerrada pelo servidor.';
            _conectando = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _erro = 'Erro ao inicializar WebSocket.';
        _conectando = false;
      });
    }
  }

  @override
  void dispose() {
    // É fundamental fechar a conexão ao sair da aba para não gastar memória
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Jogos de Hoje '),
            // Indicador visual de que está "Ao Vivo"
            if (!_conectando && _erro == null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AO VIVO', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_conectando && _jogos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Conectando ao servidor da NBA...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_erro != null && _jogos.isEmpty) {
      return Center(
        child: Text(_erro!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_jogos.isEmpty) {
      return const Center(
        child: Text('Nenhum jogo ocorrendo hoje.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _jogos.length,
      itemBuilder: (context, index) {
        final jogo = _jogos[index];
        return _buildCardPlacarLive(jogo);
      },
    );
  }

  // Você pode reaproveitar o mesmo design do seu _buildCardPlacar atual,
  // apenas adaptando para os dados do WebSocket.
  Widget _buildCardPlacarLive(dynamic jogo) {
    final equipes = jogo['equipes'] as List;
    final time1 = equipes[0];
    final time2 = equipes[1];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    CircleAvatar(backgroundColor: AppTheme.surfaceVariant, radius: 24, child: Text(time1['sigla'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 6),
                    Text(time1['sigla'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                // PLACAR DINÂMICO
                Text(time1['placar'].toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                const Text('VS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                Text(time2['placar'].toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                Column(
                  children: [
                    CircleAvatar(backgroundColor: AppTheme.surfaceVariant, radius: 24, child: Text(time2['sigla'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 6),
                    Text(time2['sigla'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}