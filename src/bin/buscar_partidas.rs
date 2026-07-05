use reqwest::header::{HeaderMap, HeaderValue};
use serde::Serialize;
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::Duration;
use std::env;

// --- Estrutura que será convertida em JSON no final ---
#[derive(Serialize)]
struct RespostaFinal {
    data: String,
    quantidade_jogos: usize,
    jogos: Vec<GameInfo>,
}

#[derive(Serialize)]
struct GameInfo {
    game_id: String,
    season: String,
    tipo_jogo: String,
    equipes: Vec<TeamScore>, // Placar isolado dos jogadores
    jogadores: Vec<PlayerGameStat>,
}

#[derive(Serialize)]
struct TeamScore {
    sigla: String,
    placar: i64,
}

#[derive(Serialize)]
struct PlayerGameStat {
    nba_player_id: i64,
    nome_completo: String,
    time_jogador: String,
    time_adversario: String,
    minutos: String,
    pts: i64,
    ast: i64,
    reb: i64,
    oreb: i64,
    dreb: i64,
    stl: i64,
    blk: i64,
    tov: i64,
    pf: i64,
    fgm: i64,
    fga: i64,
    fg_pct: f64,
    fg3m: i64,
    fg3a: i64,
    fg3_pct: f64,
    ftm: i64,
    fta: i64,
    ft_pct: f64,
    plus_minus: i64,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();
    
    if args.len() < 2 {
        eprintln!("ERRO: Data não fornecida.");
        eprintln!("Uso correto: {} <MM/DD/YYYY>", args[0]);
        std::process::exit(1);
    }

    let data_alvo = args[1].as_str();
    eprintln!("Iniciando extração de calendário e Box Scores para {}...", data_alvo);

    let client = configurar_cliente_http()?;
    let mut jogos_extraidos: Vec<GameInfo> = Vec::new();

    let url_scoreboard = "https://stats.nba.com/stats/scoreboardv2";
    let mut params_score = HashMap::new();
    params_score.insert("GameDate", data_alvo);
    params_score.insert("LeagueID", "00");
    params_score.insert("DayOffset", "0");

    let resp_score = client.get(url_scoreboard).query(&params_score).send().await?;

    let mut games_list: Vec<(String, String)> = Vec::new();

    if resp_score.status().is_success() {
        let json_score: Value = resp_score.json().await?;
        if let Some(result_sets) = json_score["resultSets"].as_array() {
            if let Some(game_header) = result_sets.iter().find(|s| s["name"] == "GameHeader") {
                let headers = game_header["headers"].as_array().unwrap();
                let rows = game_header["rowSet"].as_array().unwrap();
                
                let idx_game_id = headers.iter().position(|h| h.as_str() == Some("GAME_ID")).unwrap();
                // Pega o índice da Season (usamos unwrap_or para segurança caso a API não retorne)
                let idx_season = headers.iter().position(|h| h.as_str() == Some("SEASON")).unwrap_or(0);

                for row in rows.iter().filter_map(|r| r.as_array()) {
                    if let Some(game_id) = row[idx_game_id].as_str() {
                        let season_raw = row.get(idx_season).and_then(|v| v.as_str()).unwrap_or("");
                        
                        // Transforma "2023" em "2023-24"
                        let season_formatada = if let Ok(ano) = season_raw.parse::<u32>() {
                            format!("{}-{:02}", ano, (ano + 1) % 100)
                        } else {
                            season_raw.to_string()
                        };

                        games_list.push((game_id.to_string(), season_formatada));
                    }
                }
            }
        }
    }

    if games_list.is_empty() {
        eprintln!("Nenhum jogo encontrado para a data {}.", data_alvo);
        
        let resposta_vazia = RespostaFinal {
            data: data_alvo.to_string(),
            quantidade_jogos: 0,
            jogos: vec![],
        };
        println!("{}", serde_json::to_string_pretty(&resposta_vazia)?);
        return Ok(());
    }

    eprintln!("{} jogos encontrados. Buscando estatísticas completas...", games_list.len());
    let url_boxscore = "https://stats.nba.com/stats/boxscoretraditionalv2";
    
    for (game_id, season) in games_list {
        eprintln!("Processando Box Score do jogo: {}", game_id);

        let tipo_jogo = match game_id.chars().nth(2) {
            Some('1') => "Preseason",
            Some('2') => "Regular",
            Some('3') => "All-Star",
            Some('4') => "Playoffs",
            Some('5') => "Play-In",
            _ => "Outro",
        };
        
        let mut params_box = HashMap::new();
        params_box.insert("GameID", game_id.as_str());
        params_box.insert("StartPeriod", "0");
        params_box.insert("EndPeriod", "0");
        params_box.insert("StartRange", "0");
        params_box.insert("EndRange", "0");
        params_box.insert("RangeType", "0");

        let resp_box = client.get(url_boxscore).query(&params_box).send().await?;
        
        if resp_box.status().is_success() {
            let json_box: Value = resp_box.json().await?;
            
            let mut equipes_info = Vec::new();
            let mut jogadores_info = Vec::new();
            let mut times_no_jogo = Vec::new();

            if let Some(result_sets) = json_box["resultSets"].as_array() {
                // --- 1. EXTRAIR O PLACAR DAS EQUIPES ---
                if let Some(team_stats) = result_sets.iter().find(|s| s["name"] == "TeamStats") {
                    let headers = team_stats["headers"].as_array().unwrap();
                    let rows = team_stats["rowSet"].as_array().unwrap();
                    
                    let idx_team_abbr = headers.iter().position(|h| h.as_str() == Some("TEAM_ABBREVIATION")).unwrap();
                    let idx_pts = headers.iter().position(|h| h.as_str() == Some("PTS")).unwrap();

                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        let sigla = row[idx_team_abbr].as_str().unwrap_or("").to_string();
                        let placar = row[idx_pts].as_i64().unwrap_or(0);
                        
                        equipes_info.push(TeamScore { sigla: sigla.clone(), placar });
                        times_no_jogo.push(sigla);
                    }
                }

                // --- 2. EXTRAIR OS JOGADORES ---
                if let Some(player_stats) = result_sets.iter().find(|s| s["name"] == "PlayerStats") {
                    let headers = player_stats["headers"].as_array().unwrap();
                    let rows = player_stats["rowSet"].as_array().unwrap();
                    
                    let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);
                    
                    let idx_player_id = achar_idx("PLAYER_ID");
                    let idx_player_name = achar_idx("PLAYER_NAME");
                    let idx_team_abbr = achar_idx("TEAM_ABBREVIATION");
                    let idx_comment = achar_idx("COMMENT");
                    let idx_min = achar_idx("MIN");

                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        let comment = row[idx_comment].as_str().unwrap_or("");
                        let min = row[idx_min].as_str().unwrap_or("");

                        if comment.is_empty() && !min.is_empty() {
                            let player_id = row[idx_player_id].as_i64().unwrap_or(0);
                            let player_name = row[idx_player_name].as_str().unwrap_or("");
                            let time_jogador = row[idx_team_abbr].as_str().unwrap_or("");
                            
                            let mut time_adversario = "";
                            if times_no_jogo.len() == 2 {
                                time_adversario = if time_jogador == times_no_jogo[0] {
                                    &times_no_jogo[1]
                                } else {
                                    &times_no_jogo[0]
                                };
                            }

                            jogadores_info.push(PlayerGameStat {
                                nba_player_id: player_id,
                                nome_completo: player_name.to_string(),
                                time_jogador: time_jogador.to_string(),
                                time_adversario: time_adversario.to_string(),
                                minutos: min.to_string(),
                                pts: row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                ast: row[achar_idx("AST")].as_i64().unwrap_or(0),
                                reb: row[achar_idx("REB")].as_i64().unwrap_or(0),
                                oreb: row[achar_idx("OREB")].as_i64().unwrap_or(0),
                                dreb: row[achar_idx("DREB")].as_i64().unwrap_or(0),
                                stl: row[achar_idx("STL")].as_i64().unwrap_or(0),
                                blk: row[achar_idx("BLK")].as_i64().unwrap_or(0),
                                tov: row[achar_idx("TO")].as_i64().unwrap_or(0),
                                pf: row[achar_idx("PF")].as_i64().unwrap_or(0),
                                fgm: row[achar_idx("FGM")].as_i64().unwrap_or(0),
                                fga: row[achar_idx("FGA")].as_i64().unwrap_or(0),
                                fg_pct: row[achar_idx("FG_PCT")].as_f64().unwrap_or(0.0),
                                fg3m: row[achar_idx("FG3M")].as_i64().unwrap_or(0),
                                fg3a: row[achar_idx("FG3A")].as_i64().unwrap_or(0),
                                fg3_pct: row[achar_idx("FG3_PCT")].as_f64().unwrap_or(0.0),
                                ftm: row[achar_idx("FTM")].as_i64().unwrap_or(0),
                                fta: row[achar_idx("FTA")].as_i64().unwrap_or(0),
                                ft_pct: row[achar_idx("FT_PCT")].as_f64().unwrap_or(0.0),
                                plus_minus: row[achar_idx("PLUS_MINUS")].as_i64().unwrap_or(0),
                            });
                        }
                    }
                }
            }

            // --- 3. AGRUPAR TUDO NO JOGO ATUAL ---
            jogos_extraidos.push(GameInfo {
                game_id: game_id.clone(),
                season: season.clone(),   // <-- Passa a temporada para o JSON aqui
                tipo_jogo: tipo_jogo.to_string(),
                equipes: equipes_info,
                jogadores: jogadores_info,
            });
            
            eprintln!("  -> Jogo {} processado com sucesso.", game_id);
        }
        
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    eprintln!("Extração finalizada!");

    // --- MONTA A RESPOSTA FINAL E IMPRIME BONITO (PRETTY) ---
    let resposta_final = RespostaFinal {
        data: data_alvo.to_string(),
        quantidade_jogos: jogos_extraidos.len(),
        jogos: jogos_extraidos,
    };

    let json_output = serde_json::to_string_pretty(&resposta_final)?;
    std::fs::write("saida_teste.json", &json_output)?;
    println!("{}", json_output);

    Ok(())
}

fn configurar_cliente_http() -> Result<reqwest::Client, Box<dyn Error>> {
    let mut headers = HeaderMap::new();
    
    
    headers.insert("Host", HeaderValue::from_static("stats.nba.com"));
    headers.insert("Connection", HeaderValue::from_static("keep-alive"));
    headers.insert("User-Agent", HeaderValue::from_static("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"));
    headers.insert("Accept", HeaderValue::from_static("application/json, text/plain, */*"));
    headers.insert("Origin", HeaderValue::from_static("https://www.nba.com"));
    headers.insert("Referer", HeaderValue::from_static("https://www.nba.com/"));
    headers.insert("Accept-Language", HeaderValue::from_static("en-US,en;q=0.9,pt-BR;q=0.8,pt;q=0.7"));
    
    
    headers.insert("sec-fetch-site", HeaderValue::from_static("same-site"));
    headers.insert("sec-fetch-mode", HeaderValue::from_static("cors"));
    headers.insert("sec-fetch-dest", HeaderValue::from_static("empty"));
    headers.insert("x-nba-stats-origin", HeaderValue::from_static("stats"));
    headers.insert("x-nba-stats-token", HeaderValue::from_static("true"));

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(30)) 
        .default_headers(headers)
        .build()?;
    
    Ok(client)
}