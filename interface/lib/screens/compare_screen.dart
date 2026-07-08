
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/players_provider.dart';
import '../models/player.dart';
import '../services/nba_service.dart';
import '../theme/app_theme.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _service = NbaService();

  
  Player? _jogador1;
  Player? _jogador2;
  String? _temporada;
  String? _etapa;


  Map<String, dynamic>? _dadosComparacao;
  bool _carregando = false;
  String? _erro;

 
  final List<String> _temporadas = ['2025-26', '2024-25', '2023-24', '2022-23'];
  final Map<String, String> _etapas = {
    'regular': 'Temporada Regular',
    'playoffs': 'Playoffs',
    'all': 'Total (Ambos)',
  };

  Future<void> _executarComparacao() async {
    if (_jogador1 == null || _jogador2 == null || _temporada == null || _etapa == null) {
      setState(() => _erro = 'Por favor, preencha todos os filtros antes de comparar.');
      return;
    }
    
    if (_jogador1!.id == _jogador2!.id) {
      setState(() => _erro = 'Selecione dois jogadores diferentes para comparar.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
      _dadosComparacao = null;
    });

    try {
      final resultado = await _service.comparar(
        playerId1: _jogador1!.id,
        playerId2: _jogador2!.id,
        season: _temporada!,
        etapa: _etapa!,
      );
      setState(() => _dadosComparacao = resultado);
    } catch (e) {
      setState(() => _erro = 'Não foi possível carregar a comparação.');
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersProvider = context.watch<PlayersProvider>();
    final listaJogadores = playersProvider.jogadores;
    final todosFiltrosPreenchidos = _jogador1 != null && _jogador2 != null && _temporada != null && _etapa != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Comparar Jogadores')),
      body: Column(
        children: [
          
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  
                  DropdownButtonFormField<Player>(
                    decoration: const InputDecoration(labelText: 'Jogador 1', prefixIcon: Icon(Icons.person)),
                    value: _jogador1,
                    hint: const Text('Selecione o primeiro jogador'),
                    items: listaJogadores.map((p) {
                      return DropdownMenuItem(value: p, child: Text('${p.nome} (${p.time ?? "N/A"})'));
                    }).toList(),
                    onChanged: (v) => setState(() => _jogador1 = v),
                  ),
                  const SizedBox(height: 12),
                  // Dropdown Jogador 2
                  DropdownButtonFormField<Player>(
                    decoration: const InputDecoration(labelText: 'Jogador 2', prefixIcon: Icon(Icons.person_outline)),
                    value: _jogador2,
                    hint: const Text('Selecione o segundo jogador'),
                    items: listaJogadores.map((p) {
                      return DropdownMenuItem(value: p, child: Text('${p.nome} (${p.time ?? "N/A"})'));
                    }).toList(),
                    onChanged: (v) => setState(() => _jogador2 = v),
                  ),
                  const SizedBox(height: 12),
                
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Temporada'),
                          value: _temporada,
                          hint: const Text('Selecione'),
                          items: _temporadas.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _temporada = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Etapa'),
                          value: _etapa,
                          hint: const Text('Selecione'),
                          items: _etapas.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _etapa = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                 
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (!todosFiltrosPreenchidos || _carregando) ? null : _executarComparacao,
                      icon: _carregando 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.stacked_bar_chart),
                      label: const Text('Comparar Estatísticas'),
                    ),
                  )
                ],
              ),
            ),
          ),

         
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? _buildErro()
                    : _dadosComparacao == null
                        ? _buildEstadoVazio('Preencha os jogadores, os filtros de temporada e clique em Comparar.')
                        : _construirTabelaComparativa(_dadosComparacao!),
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
            const Icon(Icons.compare_arrows_rounded, size: 48, color: AppTheme.textSecondary),
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

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_erro!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _executarComparacao, child: const Text('Tentar Novamente')),
        ],
      ),
    );
  }

  Widget _construirTabelaComparativa(Map<String, dynamic> dados) {
    final nomeJ1 = dados['jogadores']?['jogador_1']?['nome'] ?? 'Jogador 1';
    final nomeJ2 = dados['jogadores']?['jogador_2']?['nome'] ?? 'Jogador 2';
    final timeJ1 = dados['jogadores']?['jogador_1']?['time'] ?? '';
    final timeJ2 = dados['jogadores']?['jogador_2']?['time'] ?? '';

    final List<dynamic> estatisticas = dados['estatisticas'] ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        clipBehavior: Clip.antiAlias, 
        margin: EdgeInsets.zero, 
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: DataTableTheme(
            data: DataTableThemeData(
              headingRowColor: MaterialStateProperty.all(AppTheme.surfaceVariant),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: DataTable(
                columnSpacing: 32, 
                dataRowMinHeight: 48, 
                dataRowMaxHeight: 56, 
                columns: [
                  const DataColumn(label: Text('MÉTRICA', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                  DataColumn(label: Text('$nomeJ1\n($timeJ1)', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13))),
                  DataColumn(label: Text('$nomeJ2\n($timeJ2)', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary, fontSize: 13))),
                ],
                rows: estatisticas.map((stat) {
                  final metrica = stat['metrica'].toString();
                  final val1 = stat['jogador_1'];
                  final val2 = stat['jogador_2'];
                  final vantagem = stat['vantagem'] ?? 0; // 1 = Jogador 1, 2 = Jogador 2, 0 = Empate

                  final estiloJ1 = TextStyle(
                    fontWeight: vantagem == 1 ? FontWeight.bold : FontWeight.normal,
                    fontSize: vantagem == 1 ? 15 : 14,
                    color: vantagem == 1 ? AppTheme.success : AppTheme.textPrimary,
                  );

                  final estiloJ2 = TextStyle(
                    fontWeight: vantagem == 2 ? FontWeight.bold : FontWeight.normal,
                    fontSize: vantagem == 2 ? 15 : 14,
                    color: vantagem == 2 ? AppTheme.success : AppTheme.textPrimary,
                  );

                  return DataRow(cells: [
                    DataCell(Text(metrica, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textSecondary))),
                    DataCell(Text(val1.toString(), style: estiloJ1)),
                    DataCell(Text(val2.toString(), style: estiloJ2)),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
