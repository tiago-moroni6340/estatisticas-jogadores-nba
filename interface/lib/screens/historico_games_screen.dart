import 'package:flutter/material.dart';
import '../services/nba_service.dart';
import '../theme/app_theme.dart';

class HistoricoGamesScreen extends StatefulWidget {
  const HistoricoGamesScreen({super.key});

  @override
  State<HistoricoGamesScreen> createState() => _HistoricoGamesScreenState();
}

class _HistoricoGamesScreenState extends State<HistoricoGamesScreen> {
  final _service = NbaService();
  final _dataController = TextEditingController();

  List<dynamic> _jogos = [];
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? selecionado = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2028),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: AppTheme.primary, surface: AppTheme.surface),
          ),
          child: child!,
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _dataController.text = 
            "${selecionado.day.toString().padLeft(2, '0')}/${selecionado.month.toString().padLeft(2, '0')}/${selecionado.year}";
      });
      _buscarPartidas();
    }
  }

  Future<void> _buscarPartidas() async {
    if (_dataController.text.isEmpty) return;
    setState(() {
      _carregando = true;
      _erro = null;
      _jogos = [];
    });

    try {
      final dados = await _service.jogosPorData(_dataController.text);
      if (!mounted) return;

      setState(() => _jogos = dados);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Nenhum jogo encontrado ou falha na conexão.');
    } finally {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jaFezBusca = _dataController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Partidas e Box Scores')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dataController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Data dos Jogos',
                      hintText: 'Selecione uma data...',
                      prefixIcon: Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                    ),
                    onTap: () => _selecionarData(context),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _carregando ? null : _buscarPartidas,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? Center(child: Text(_erro!, style: const TextStyle(color: Colors.red)))
                    : !jaFezBusca
                        ? _buildEstadoVazio('Toque no calendário acima para escolher uma data e carregar os placares.')
                        : _jogos.isEmpty
                            ? _buildEstadoVazio('Não houve jogos programados para a data selecionada.')
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _jogos.length,
                                itemBuilder: (context, index) {
                                  final jogo = _jogos[index];
                                  return _buildCardPlacar(jogo);
                                },
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVazio(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_basketball_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPlacar(dynamic jogo) {
    final equipes = jogo['equipes'] as List;
    final time1 = equipes[0];
    final time2 = equipes[1];
    final tipoJogo = jogo['tipo_jogo'] ?? 'Regular';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirPainelEstatisticas(jogo),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(tipoJogo.toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
                  Text(time1['placar'].toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text('VS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  Text(time2['placar'].toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Column(
                    children: [
                      CircleAvatar(backgroundColor: AppTheme.surfaceVariant, radius: 24, child: Text(time2['sigla'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 6),
                      Text(time2['sigla'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 14, color: AppTheme.textSecondary),
                  SizedBox(width: 4),
                  Text('Toque para abrir estatísticas dos atletas', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _abrirPainelEstatisticas(dynamic jogo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return _PainelEstatisticasJogo(jogo: jogo);
      },
    );
  }
}

class _PainelEstatisticasJogo extends StatefulWidget {
  final dynamic jogo;
  const _PainelEstatisticasJogo({required this.jogo});

  @override
  State<_PainelEstatisticasJogo> createState() => _PainelEstatisticasJogoState();
}

class _PainelEstatisticasJogoState extends State<_PainelEstatisticasJogo> {
  String? _timeSelecionado;
  dynamic _jogadorSelecionado;

  @override
  void initState() {
    super.initState();
    final equipes = widget.jogo['equipes'] as List;
    _timeSelecionado = equipes[0]['sigla'];
  }

  @override
  Widget build(BuildContext context) {
    final equipes = widget.jogo['equipes'] as List;
    final listaJogadoresCompleta = widget.jogo['jogadores'] as List;
    final jogadoresDoTime = listaJogadoresCompleta.where((j) => j['time_jogador'] == _timeSelecionado).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estatísticas da Partida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Filtrar por Equipe'),
                      value: _timeSelecionado,
                      items: equipes.map((t) => DropdownMenuItem<String>(value: t['sigla'].toString(), child: Text(t['sigla'].toString()))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _timeSelecionado = v;
                          _jogadorSelecionado = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<dynamic>(
                      decoration: const InputDecoration(labelText: 'Selecionar Jogador'),
                      value: _jogadorSelecionado,
                      hint: const Text('Selecione um atleta'),
                      items: jogadoresDoTime.map((j) => DropdownMenuItem<dynamic>(value: j, child: Text(j['nome_completo'].toString()))).toList(),
                      onChanged: (v) => setState(() => _jogadorSelecionado = v),
                    ),
                    const SizedBox(height: 20),
                    if (_jogadorSelecionado != null) ...[
                      Text('Desempenho de ${_jogadorSelecionado['nome_completo']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      const SizedBox(height: 10),
                      _buildTabelaMetricasDoJogador(_jogadorSelecionado),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('Escolha um jogador para conferir o box score.', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabelaMetricasDoJogador(dynamic jogador) {
    final Map<String, String> chavesDesejadas = {
      'minutos': 'Minutos em Quadra',
      'pts': 'Pontos (PTS)',
      'ast': 'Assistências (AST)',
      'reb': 'Rebotes Totais (REB)',
      'oreb': 'Rebotes Ofensivos',
      'dreb': 'Rebotes Defensivos',
      'stl': 'Roubos de Bola (STL)',
      'blk': 'Bloqueios (BLK)',
      'tov': 'Turnovers (TOV)',
      'fgm': 'Arremessos Convertidos',
      'fga': 'Tentativas de Arremesso',
      'fg_pct': 'Aproveitamento de Quadra',
      'fg3m': 'Bolas de 3 Convertidas',
      'fg3a': 'Tentativas de 3 Pts',
      'fg3_pct': 'Aproveitamento de 3 Pts',
      'ftm': 'Lances Livres Convertidos',
      'fta': 'Tentativas de Lance Livre',
      'ft_pct': 'Aproveitamento de LL',
      'plus_minus': 'Saldo em Quadra (+/-)',
    };

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceVariant.withOpacity(0.5)),
      ),
      child: Table(
        border: TableBorder.symmetric(inside: const BorderSide(color: AppTheme.surfaceVariant, width: 0.5)),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
        },
        children: chavesDesejadas.entries.map((entry) {
          final valorRaw = jogador[entry.key] ?? 0;
          String valorTratado = valorRaw.toString();
          if (entry.key.contains('pct')) {
            double pct = double.tryParse(valorRaw.toString()) ?? 0.0;
            valorTratado = "${(pct * 100).toStringAsFixed(1)}%";
          }

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                child: Text(entry.value, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                child: Text(valorTratado, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}