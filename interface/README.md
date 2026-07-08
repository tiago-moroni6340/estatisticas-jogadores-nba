# NBA Stats — App Flutter

App em Flutter (tema escuro) que consome a API descrita em `openai.yaml`,
permitindo navegar por **Jogadores**, **Times** e **Favoritos**, além de
autenticação (login / criar conta) e visualização de estatísticas por
jogador.

## Como rodar

1. Instale as dependências:
   ```bash
   flutter pub get
   ```
2. Configure a URL da sua API em `lib/services/api_client.dart`:
   ```dart
   static const String baseUrl = 'https://SEU-BACKEND-AQUI.com';
   ```
3. Rode o app:
   ```bash
   flutter run
   ```

## Estrutura

```
lib/
  main.dart                     -> ponto de entrada, providers e tema
  theme/app_theme.dart          -> tema escuro
  models/
    player.dart                 -> modelo de jogador (parsing defensivo)
    team.dart                   -> lista estática dos 30 times da NBA
  services/
    api_client.dart             -> cliente HTTP central (token, headers, erros)
    auth_service.dart           -> login, criar conta, refresh, deletar conta
    nba_service.dart            -> todos os endpoints de /nba_dados
    favorites_service.dart      -> favoritos salvos localmente
  providers/
    auth_provider.dart
    players_provider.dart
    favorites_provider.dart
  screens/
    login_screen.dart / register_screen.dart
    home_screen.dart            -> navegação por abas (Jogadores/Times/Favoritos)
    players_screen.dart         -> lista + busca de jogadores
    player_detail_screen.dart   -> estatísticas (regular/playoffs/carreira)
    teams_screen.dart / team_players_screen.dart
    favorites_screen.dart
  widgets/
    player_card.dart
```

## ⚠️ Pontos importantes sobre a API (`openai.yaml`)

O arquivo OpenAPI fornecido define os **endpoints**, mas quase todos os
retornos usam `schema: {}` — ou seja, **o formato exato do JSON de resposta
não está documentado**. Para o app funcionar 100% com seus dados reais,
você provavelmente vai precisar ajustar:

1. **`lib/models/player.dart`** — a função `Player.fromJson` tenta várias
   chaves comuns (`id`, `nome`, `name`, `time`, `team`, etc). Ajuste para o
   nome real dos campos que sua API retorna em
   `/nba_dados/perfil_jogadores`.

2. **`lib/services/auth_service.dart`** — o método `login()` assume que a
   resposta tem um campo `access_token` (padrão comum do FastAPI). Se sua
   API retornar outro nome de campo, ajuste ali.

3. **Times**: a API **não possui nenhum endpoint de listagem de times**
   (só trabalha por `nba_player_id`). Por isso, a tela "Times" usa uma
   lista estática das 30 franquias (`models/team.dart`) e faz o
   agrupamento no app, a partir do campo de time devolvido no perfil do
   jogador. Se sua API não devolver o time no perfil do jogador, essa tela
   precisará de uma fonte de dados adicional.

4. **Favoritos**: também não existe endpoint de favoritos na API — a
   funcionalidade foi implementada localmente no dispositivo
   (`shared_preferences`), guardando os `nba_player_id` favoritados.

5. **Autenticação**: quase todos os endpoints de dados exigem
   `OAuth2PasswordBearer` (Bearer token). O `ApiClient` já injeta o header
   `Authorization: Bearer <token>` automaticamente em todas as chamadas,
   exceto `/nba_dados/player_stats/games`, `/nba_dados/player_stats/timeline`
   e `/nba_dados/` (que no yaml aparecem sem o bloco `security`).

## Próximos passos sugeridos

- Adicionar as telas de **Ranking** (`/player_stats/ranking`) e
  **Comparar Jogadores** (`/player_stats/compare`), já que os métodos
  correspondentes (`ranking()` e `comparar()`) já estão prontos em
  `NbaService`.
- Adicionar paginação/lazy loading caso `/nba_dados/perfil_jogadores`
  retorne uma lista muito grande.
- Trocar o parsing genérico de estatísticas (grade de chave/valor) por
  cards nomeados assim que você souber os nomes reais dos campos
  (ex: PTS, REB, AST).
