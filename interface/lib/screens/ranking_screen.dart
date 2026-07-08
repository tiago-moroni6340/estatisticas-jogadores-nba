
import 'package:flutter/material.dart';
import '../services/nba_service.dart';
import '../theme/app_theme.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _service = NbaService();

  
  String? _temporada;
  String? _etapa;
  String _metricaSelecionada = 'pts'; 

 
  List<dynamic> _listaRanking = [];
  bool _carregando = false;
  String? _erro;


  final List<String> _temporadas = ['2025-26', '2024-25', '2023-24', '2022-23'];
  
  final Map<String, String> _etapas = {
    'regular': 'Temporada Regular',
    'playoffs': 'Playoffs',
    'all': 'Total unificado',
  };

  final Map<String, String> _metricasAmigaveis = {
    'pts': 'Pontos',
    'ast': 'Assistências',
    'reb': 'Rebotes',
    'min': 'Minutos',
    'stl': 'Roubos',
    'blk': 'Bloqueios',
    'tov': 'Turnovers',
    'fg_pct': '% de Quadra',
    'fg3_pct': '% de 3 Pts',
    'ft_pct': '% Lance Livre',
  };

  @override
  void initState() {
    super.initState();
 
  }

  Future<void> _buscarRanking() async {
    
    if (_temporada == null || _etapa == null) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final dados = await _service.ranking(
        season: _temporada!,
        etapa: _etapa!,
        tipoEstatistica: _metricaSelecionada,
        limit: 10,
      );
      
      if (!mounted) return; 

      setState(() => _listaRanking = dados);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível carregar o ranking de líderes.');
    } finally {
      if (!mounted) return; 
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final jaBuscou = _temporada != null && _etapa != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Líderes de Estatísticas')),
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Temporada', 
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    ),
                    value: _temporada,
                    hint: const Text('Selecione', style: TextStyle(fontSize: 13)),
                    items: _temporadas.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      setState(() => _temporada = v);
                      _buscarRanking();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Etapa', 
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    ),
                    value: _etapa,
                    hint: const Text('Selecione', style: TextStyle(fontSize: 13)),
                    items: _etapas.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) {
                      setState(() => _etapa = v);
                      _buscarRanking();
                    },
                  ),
                ),
              ],
            ),
          ),

          
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _metricasAmigaveis.entries.map((entry) {
                final ativa = _metricaSelecionada == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: ativa,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: ativa ? Colors.white : AppTheme.textSecondary,
                      fontWeight: ativa ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _metricaSelecionada = entry.key);
                        
                        if (jaBuscou) _buscarRanking();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? _buildErro()
                    : !jaBuscou
                        ? _buildEstadoVazio('Defina uma Temporada e uma Etapa nos filtros acima para gerar o ranking.')
                        : _listaRanking.isEmpty
                            ? _buildEstadoVazio('Nenhum dado encontrado para esta métrica.')
                            : _buildTabelaRanking(),
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
            const Icon(Icons.bar_chart_outlined, size: 48, color: AppTheme.textSecondary),
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

  Widget _buildTabelaRanking() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: MaterialStateProperty.all(AppTheme.surfaceVariant),
            columns: [
              const DataColumn(label: Text('POS', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              const DataColumn(label: Text('JOGADOR', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              DataColumn(
                label: Text(
                  _metricasAmigaveis[_metricaSelecionada]!.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                numeric: true,
              ),
            ],
            rows: _listaRanking.map((item) {
              final posicao = item['posicao'] ?? 0;
              final nome = item['nome'] ?? 'N/A';
              final time = item['time'] ?? '';
              final valorMetrica = item[_metricaSelecionada] ?? item['valor'] ?? 0;

              Color? corPosicao;
              if (posicao == 1) corPosicao = AppTheme.favorite;
              if (posicao == 2) corPosicao = const Color(0xFFC0C0C0);
              if (posicao == 3) corPosicao = const Color(0xFFCD7F32);

              return DataRow(cells: [
                DataCell(
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: corPosicao ?? AppTheme.surfaceVariant,
                    child: Text(
                      posicao.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: corPosicao != null ? Colors.black : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    valorMetrica.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_erro!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _buscarRanking, child: const Text('Tentar Novamente')),
        ],
      ),
    );
  }
}
