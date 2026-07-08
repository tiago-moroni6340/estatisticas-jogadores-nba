import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/favorites_provider.dart';
import '../services/nba_service.dart';
import '../theme/app_theme.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = NbaService();
  late TabController _tabController;

  // Estados dos Dados
  Map<String, dynamic>? _regular;
  Map<String, dynamic>? _playoffs;
  Map<String, dynamic>? _total;
  List<dynamic> _historicoJogos = [];

  // Estados de Controle de Filtro
  final List<String> _temporadas = ['Geral', '2025-26', '2024-25', '2023-24', '2022-23'];
  String _temporadaRegularSelecionada = 'Geral';
  String _temporadaPlayoffsSelecionada = 'Geral';

  bool _carregandoRegular = true;
  bool _carregandoPlayoffs = true;
  bool _carregandoTotal = true;
  bool _carregandoHistorico = true;
  String? _erro;

  // AJUSTADO: Dicionário agora mapeia os apelidos vindos da API para o nome completo da franquia
  String _obterNomeCompletoTime(String? nomeTime) {
    if (nomeTime == null || nomeTime.trim().isEmpty || nomeTime == 'N/A' || nomeTime == 'Sem time') return 'Sem Time';
    
    final timesNba = {
      'Hawks': 'Atlanta Hawks',
      'Celtics': 'Boston Celtics',
      'Nets': 'Brooklyn Nets',
      'Hornets': 'Charlotte Hornets',
      'Bulls': 'Chicago Bulls',
      'Cavaliers': 'Cleveland Cavaliers',
      'Mavericks': 'Dallas Mavericks',
      'Nuggets': 'Denver Nuggets',
      'Pistons': 'Detroit Pistons',
      'Warriors': 'Golden State Warriors',
      'Rockets': 'Houston Rockets',
      'Pacers': 'Indiana Pacers',
      'Clippers': 'Los Angeles Clippers',
      'Lakers': 'Los Angeles Lakers',
      'Grizzlies': 'Memphis Grizzlies',
      'Heat': 'Miami Heat',
      'Bucks': 'Milwaukee Bucks',
      'Timberwolves': 'Minnesota Timberwolves',
      'Pelicans': 'New Orleans Pelicans',
      'Knicks': 'New York Knicks',
      'Thunder': 'Oklahoma City Thunder',
      'Magic': 'Orlando Magic',
      '76ers': 'Philadelphia 76ers',
      'Suns': 'Phoenix Suns',
      'Trail Blazers': 'Portland Trail Blazers',
      'Kings': 'Sacramento Kings',
      'Spurs': 'San Antonio Spurs',
      'Raptors': 'Toronto Raptors',
      'Jazz': 'Utah Jazz',
      'Wizards': 'Washington Wizards',
    };

    return timesNba[nomeTime.trim()] ?? nomeTime;
  }

  // AJUSTADO: Função para traduzir o apelido do time para o padrão de URL da ESPN
  String _obterSlugEspnPorNome(String? nome) {
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
      'Warriors': 'gs',
      'Rockets': 'hou',
      'Pacers': 'ind',
      'Clippers': 'lac',
      'Lakers': 'lal',
      'Grizzlies': 'mem',
      'Heat': 'mia',
      'Bucks': 'mil',
      'Timberwolves': 'min',
      'Pelicans': 'nop',
      'Knicks': 'ny',
      'Thunder': 'okc',
      'Magic': 'orl',
      '76ers': 'phi',
      'Suns': 'phx',
      'Trail Blazers': 'por',
      'Kings': 'sac',
      'Spurs': 'sas',
      'Raptors': 'tor',
      'Jazz': 'utah',
      'Wizards': 'was',
    };

    return mapaTimes[nome.trim()] ?? nome.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _erro = null);
    _buscarRegular();
    _buscarPlayoffs();
    _buscarTotal();
    _buscarHistorico();
  }

  Future<void> _buscarRegular() async {
    setState(() => _carregandoRegular = true);
    try {
      if (_temporadaRegularSelecionada == 'Geral') {
        final res = await _service.estatisticaCarreiraRegularSeason(widget.player.id);
        if (!mounted) return;
        setState(() => _regular = res);
      } else {
        final res = await _service.estatisticaRegularSeason(widget.player.id, _temporadaRegularSelecionada);
        if (!mounted) return;
        setState(() => _regular = res);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Erro ao buscar dados da temporada regular.');
    } finally {
      if (!mounted) return;
      setState(() => _carregandoRegular = false);
    }
  }

  Future<void> _buscarPlayoffs() async {
    setState(() => _carregandoPlayoffs = true);
    try {
      if (_temporadaPlayoffsSelecionada == 'Geral') {
        final res = await _service.estatisticaCarreiraPlayoffs(widget.player.id);
        if (!mounted) return;
        setState(() => _playoffs = res);
      } else {
        final res = await _service.estatisticaPlayoffs(widget.player.id, _temporadaPlayoffsSelecionada);
        if (!mounted) return;
        setState(() => _playoffs = res);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Erro ao buscar dados dos playoffs.');
    } finally {
      if (!mounted) return;
      setState(() => _carregandoPlayoffs = false);
    }
  }

  Future<void> _buscarTotal() async {
    setState(() => _carregandoTotal = true);
    try {
      final res = await _service.estatisticaCarreiraTotal(widget.player.id);
      if (!mounted) return;
      setState(() => _total = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Erro ao buscar totais da carreira.');
    } finally {
      if (!mounted) return;
      setState(() => _carregandoTotal = false);
    }
  }

  Future<void> _buscarHistorico() async {
    setState(() => _carregandoHistorico = true);
    try {
      final res = await _service.timelineJogador(playerId: widget.player.id, temporada: '2025-26');
      if (!mounted) return;
      setState(() => _historicoJogos = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Erro ao buscar histórico de partidas.');
    } finally {
      if (!mounted) return;
      setState(() => _carregandoHistorico = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = context.watch<FavoritesProvider>();
    final favoritado = favoritos.isFavorito(widget.player.id);

    final dadosPessoais = widget.player.raw;
    final escola = dadosPessoais['escola'] ?? 'N/A';
    final pais = dadosPessoais['pais'] ?? 'N/A';
    final peso = dadosPessoais['peso'] ?? 'N/A';
    final altura = dadosPessoais['altura'] ?? 'N/A';
    final numeroCamisa = dadosPessoais['numero_camisa'] ?? '';

    final nomeCompletoTimeAtual = _obterNomeCompletoTime(widget.player.time);
    final slugTime = _obterSlugEspnPorNome(widget.player.time);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.player.nome),
        actions: [
          IconButton(
            icon: Icon(
              favoritado ? Icons.star : Icons.star_border,
              color: favoritado ? AppTheme.favorite : null,
            ),
            onPressed: () => favoritos.alternar(widget.player.id),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.surfaceVariant,
                          backgroundImage: NetworkImage(
                            widget.player.fotoOficialNba
                          ),
                          onBackgroundImageError: (_, __) {},
                        ),
                        if (slugTime.isNotEmpty && widget.player.time != 'Sem time' && widget.player.time != 'N/A')
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Image.network(
                                // MODIFICADO: Agora consome o slug correto mapeado a partir do nome
                                'https://a.espncdn.com/i/teamlogos/nba/500/$slugTime.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.sports_basketball, size: 14, color: Colors.orange),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.player.nome, 
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 22)
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$nomeCompletoTimeAtual • ${widget.player.posicao ?? "N/A"}',
                                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (numeroCamisa.toString().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text('#$numeroCamisa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
                                )
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBadgePessoal('ALTURA', altura.toString()),
                      _buildBadgePessoal('PESO', peso.toString().isNotEmpty && peso != 'N/A' ? '$peso lbs' : 'N/A'),
                      _buildBadgePessoal('ORIGEM', pais.toString()),
                      _buildBadgePessoal('ESCOLA', escola.toString(), isLast: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Temp. Regular'),
              Tab(text: 'Playoffs'),
              Tab(text: 'Carreira'),
              Tab(text: 'Histórico (10J)'),
            ],
          ),
          Expanded(
            child: _erro != null
                ? Center(child: Text(_erro!, style: const TextStyle(color: Colors.red)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _construirAbaFiltrada(
                        carregando: _carregandoRegular,
                        dados: _regular,
                        valorSelecionado: _temporadaRegularSelecionada,
                        isDadosGerais: _temporadaRegularSelecionada == 'Geral',
                        onMudou: (novaTemporada) {
                          setState(() => _temporadaRegularSelecionada = novaTemporada!);
                          _buscarRegular();
                        },
                      ),
                      _construirAbaFiltrada(
                        carregando: _carregandoPlayoffs,
                        dados: _playoffs,
                        valorSelecionado: _temporadaPlayoffsSelecionada,
                        isDadosGerais: _temporadaPlayoffsSelecionada == 'Geral',
                        onMudou: (novaTemporada) {
                          setState(() => _temporadaPlayoffsSelecionada = novaTemporada!);
                          _buscarPlayoffs();
                        },
                      ),
                      _carregandoTotal
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              child: _EstatisticasFormView(
                                dados: _total, 
                                isDadosGerais: true,
                                obterNomeTime: _obterNomeCompletoTime,
                              ),
                            ),
                      _carregandoHistorico
                          ? const Center(child: CircularProgressIndicator())
                          : _construirAbaTimeline(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgePessoal(String label, String value, {bool isLast = false, String school = ''}) {
    final displayValue = label == 'ESCOLA' ? school : value;
    return Container(
      margin: EdgeInsets.only(right: isLast ? 0 : 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceVariant.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label, 
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
          const SizedBox(height: 3),
          Text(
            displayValue, 
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)
          ),
        ],
      ),
    );
  }

  Widget _construirAbaFiltrada({
    required bool carregando,
    required Map<String, dynamic>? dados,
    required String valorSelecionado,
    required bool isDadosGerais,
    required ValueChanged<String?> onMudou,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filtrar Temporada:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              DropdownButton<String>(
                value: valorSelecionado,
                items: _temporadas.map((String temp) {
                  return DropdownMenuItem<String>(value: temp, child: Text(temp));
                }).toList(),
                onChanged: onMudou,
              ),
            ],
          ),
        ),
        Expanded(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: _EstatisticasFormView(
                    dados: dados, 
                    isDadosGerais: isDadosGerais,
                    obterNomeTime: _obterNomeCompletoTime,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _construirAbaTimeline() {
    if (_historicoJogos.isEmpty) {
      return const Center(child: Text('Nenhuma partida recente registrada.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _historicoJogos.length,
      itemBuilder: (context, index) {
        final jogo = _historicoJogos[index];
        final matchup = jogo['matchup'] ?? 'NBA Game';
        final wl = jogo['wl'] ?? '-';
        final pts = jogo['pts'] ?? 0;
        final ast = jogo['ast'] ?? 0;
        final reb = jogo['reb'] ?? 0;
        
        final dataCompleta = jogo['game_date']?.toString() ?? '';
        final dataLimpa = dataCompleta.contains('T') ? dataCompleta.split('T').first : dataCompleta;
        final ganhou = wl == 'W';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            onTap: () => _abrirDetalhesJogoTimeline(jogo),
            leading: CircleAvatar(
              backgroundColor: ganhou ? AppTheme.success.withOpacity(0.2) : Theme.of(context).colorScheme.error.withOpacity(0.2),
              child: Text(
                wl,
                style: TextStyle(fontWeight: FontWeight.bold, color: ganhou ? AppTheme.success : Theme.of(context).colorScheme.error),
              ),
            ),
            title: Text(matchup, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$dataLimpa • ${jogo['tipo_temporada'] ?? "Regular"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${pts} PTS • ${ast} AST • ${reb} REB',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  void _abrirDetalhesJogoTimeline(dynamic jogo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Box Score: ${jogo['matchup']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
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
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _EstatisticasFormView(
                      dados: Map<String, dynamic>.from(jogo),
                      isDadosGerais: true,
                      obterNomeTime: _obterNomeCompletoTime,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EstatisticasFormView extends StatelessWidget {
  final Map<String, dynamic>? dados;
  final bool isDadosGerais;
  final String Function(String?) obterNomeTime;

  const _EstatisticasFormView({
    required this.dados, 
    required this.isDadosGerais,
    required this.obterNomeTime,
  });

  @override
  Widget build(BuildContext context) {
    if (dados == null || dados!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Sem dados disponíveis.', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    final metricaPrincipalChaves = ['pts', 'ast', 'reb', 'min', 'minutos', 'gp', 'gs'];

    final chavesIgnoradas = [
      'id', 'nba_player_id', 'season_id', 'game_id', 'game_date', 
      'tipo_temporada', 'matchup', 'wl', 'player_id', 'quantidade_jogos', 
      'team_abbreviation', 'player_age'
    ];

    final List<MapEntry<String, dynamic>> principais = [];
    final List<MapEntry<String, dynamic>> secundarias = [];

    for (var entry in dados!.entries) {
      if (chavesIgnoradas.contains(entry.key)) continue;
      if (metricaPrincipalChaves.contains(entry.key)) {
        principais.add(entry);
      } else {
        secundarias.add(entry);
      }
    }

    final timeTemporada = dados!['team_abbreviation'] ?? 'N/A';
    final idadeTemporada = dados!['player_age'] ?? 'N/A';

    final nomeCompletoTimeTemporada = obterNomeTime(timeTemporada.toString());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDadosGerais) ...[
            _buildSecaoTitulo('Informações da Temporada'),
            _buildFormRow([
              _FormItem(label: 'Equipe Atuante', value: nomeCompletoTimeTemporada),
              _FormItem(label: 'Idade na Temporada', value: '${idadeTemporada.toString().split('.').first} anos'),
            ]),
            const SizedBox(height: 16),
          ],

          if (principais.isNotEmpty) ...[
            _buildSecaoTitulo('Métricas Principais'),
            _buildFormGrid(principais),
            const SizedBox(height: 16),
          ],

          if (secundarias.isNotEmpty) ...[
            _buildSecaoTitulo('Outras Estatísticas'),
            _buildFormGrid(secundarias),
          ],
        ],
      ),
    );
  }

  Widget _buildSecaoTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        titulo,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildFormGrid(List<MapEntry<String, dynamic>> itens) {
    List<Widget> rows = [];
    for (int i = 0; i < itens.length; i += 2) {
      final item1 = _converterEntry(itens[i]);
      _FormItem? item2;
      if (i + 1 < itens.length) {
        item2 = _converterEntry(itens[i + 1]);
      }
      rows.add(_buildFormRow([item1, if (item2 != null) item2]));
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceVariant.withOpacity(0.5)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildFormRow(List<_FormItem> items) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.surfaceVariant, width: 0.5)),
      ),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  _FormItem _converterEntry(MapEntry<String, dynamic> entrada) {
    final dicionario = {
      'pts': 'Pontos (PTS)',
      'ast': 'Assistências (AST)',
      'reb': 'Rebotes (REB)',
      'min': 'Minutos',
      'minutos': 'Minutos',
      'gp': 'Partidas (GP)',
      'gs': 'Titular (GS)',
      'stl': 'Roubos (STL)',
      'blk': 'Bloqueios (BLK)',
      'tov': 'Turnovers',
      'pf': 'Faltas (PF)',
      'fga': 'Arremessos Tent.',
      'fgm': 'Arremessos Conv.',
      'fg_pct': 'Aproveit. FG',
      'fg3m': 'Bolas 3 Conv.',
      'fg3a': 'Bolas 3 Tent.',
      'fg3_pct': 'Aproveit. 3P',
      'ftm': 'Lances Livres Conv.',
      'fta': 'Lances Livres Tent.',
      'ft_pct': 'Aproveit. LL',
      'plus_minus': 'Saldo (+/-)',
      'oreb': 'Reb. Ofensivos',
      'dreb': 'Reb. Defensivos',
    };

    final label = dicionario[entrada.key] ?? entrada.key.replaceAll('_', ' ').toUpperCase();
    String valorTratado = entrada.value.toString();

    if (entrada.key.contains('pct')) {
      double pct = double.tryParse(entrada.value.toString()) ?? 0.0;
      valorTratado = "${(pct * 100).toStringAsFixed(1)}%";
    }

    return _FormItem(label: label, value: valorTratado);
  }
}

class _FormItem {
  final String label;
  final String value;
  const _FormItem({required this.label, required this.value});
}