
class Team {
  final String sigla;
  final String nome;

  const Team({required this.sigla, required this.nome});

  static const List<Team> todos = [
    Team(sigla: 'ATL', nome: 'Atlanta Hawks'),
    Team(sigla: 'BOS', nome: 'Boston Celtics'),
    Team(sigla: 'BKN', nome: 'Brooklyn Nets'),
    Team(sigla: 'CHA', nome: 'Charlotte Hornets'),
    Team(sigla: 'CHI', nome: 'Chicago Bulls'),
    Team(sigla: 'CLE', nome: 'Cleveland Cavaliers'),
    Team(sigla: 'DAL', nome: 'Dallas Mavericks'),
    Team(sigla: 'DEN', nome: 'Denver Nuggets'),
    Team(sigla: 'DET', nome: 'Detroit Pistons'),
    Team(sigla: 'GSW', nome: 'Golden State Warriors'),
    Team(sigla: 'HOU', nome: 'Houston Rockets'),
    Team(sigla: 'IND', nome: 'Indiana Pacers'),
    Team(sigla: 'LAC', nome: 'LA Clippers'),
    Team(sigla: 'LAL', nome: 'Los Angeles Lakers'),
    Team(sigla: 'MEM', nome: 'Memphis Grizzlies'),
    Team(sigla: 'MIA', nome: 'Miami Heat'),
    Team(sigla: 'MIL', nome: 'Milwaukee Bucks'),
    Team(sigla: 'MIN', nome: 'Minnesota Timberwolves'),
    Team(sigla: 'NO', nome: 'New Orleans Pelicans'),
    Team(sigla: 'NYK', nome: 'New York Knicks'),
    Team(sigla: 'OKC', nome: 'Oklahoma City Thunder'),
    Team(sigla: 'ORL', nome: 'Orlando Magic'),
    Team(sigla: 'PHI', nome: 'Philadelphia 76ers'),
    Team(sigla: 'PHX', nome: 'Phoenix Suns'),
    Team(sigla: 'POR', nome: 'Portland Trail Blazers'),
    Team(sigla: 'SAC', nome: 'Sacramento Kings'),
    Team(sigla: 'SAS', nome: 'San Antonio Spurs'),
    Team(sigla: 'TOR', nome: 'Toronto Raptors'),
    Team(sigla: 'UTAH', nome: 'Utah Jazz'),
    Team(sigla: 'WAS', nome: 'Washington Wizards'),
  ];
}
