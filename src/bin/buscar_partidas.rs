use reqwest::header::{
    HeaderMap, HeaderValue
};
use rusqlite::{params, Connection};
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::Duration;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {

    let args: Vec<String> = env::args().collect();
    
    // Verifica se a data foi passada. Se não foi, encerra com uma mensagem de erro útil.
    if args.len() < 2 {
        eprintln!("ERRO: Data não fornecida.");
        eprintln!("Uso correto: {} <MM/DD/YYYY>", args[0]);
        std::process::exit(1);
    }

    // Pega o primeiro argumento passado após o nome do programa
    let data_alvo = args[1].as_str();

    println!("Iniciando extração de calendário e Box Scores completos...");

    let client = configurar_cliente_http()?;
    let mut conn = Connection::open(r"C:\Users\moron\Documents\nba_stats\nba_dados.db")?;
    
    
    conn.execute(
        "CREATE TABLE IF NOT EXISTS stats_partida_individual (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id TEXT,
            data_jogo TEXT,
            nba_player_id INTEGER,
            nome_completo TEXT,
            time_jogador TEXT,
            time_adversario TEXT,
            minutos TEXT,
            pts INTEGER,
            ast INTEGER,
            reb INTEGER,
            oreb INTEGER,
            dreb INTEGER,
            stl INTEGER,
            blk INTEGER,
            tov INTEGER,
            pf INTEGER,
            fgm INTEGER,
            fga INTEGER,
            fg_pct REAL,
            fg3m INTEGER,
            fg3a INTEGER,
            fg3_pct REAL,
            ftm INTEGER,
            fta INTEGER,
            ft_pct REAL,
            plus_minus INTEGER,
            UNIQUE(game_id, nba_player_id)
        )",
        [],
    )?;

    
    let url_scoreboard = "https://stats.nba.com/stats/scoreboardv2";
    
    let mut params_score = HashMap::new();
    params_score.insert("GameDate", data_alvo);
    params_score.insert("LeagueID", "00");
    params_score.insert("DayOffset", "0");

    let resp_score = client.get(url_scoreboard).query(&params_score).send().await?;
    let mut game_ids = Vec::new();

    if resp_score.status().is_success() {
        let json_score: Value = resp_score.json().await?;
        
        if let Some(result_sets) = json_score["resultSets"].as_array() {
            if let Some(game_header) = result_sets.iter().find(|s| s["name"] == "GameHeader") {
                let headers = game_header["headers"].as_array().unwrap();
                let rows = game_header["rowSet"].as_array().unwrap();
                let idx_game_id = headers.iter().position(|h| h.as_str() == Some("GAME_ID")).unwrap();

                for row in rows.iter().filter_map(|r| r.as_array()) {
                    if let Some(game_id) = row[idx_game_id].as_str() {
                        game_ids.push(game_id.to_string());
                    }
                }
            }
        }
    }

    if game_ids.is_empty() {
        println!("Nenhum jogo encontrado para a data {}.", data_alvo);
        return Ok(());
    }

    println!("{} jogos encontrados. Buscando estatísticas completas...", game_ids.len());

    let url_boxscore = "https://stats.nba.com/stats/boxscoretraditionalv2";
    
    for game_id in game_ids {
        println!("Processando Box Score do jogo: {}", game_id);
        
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
            let tx = conn.transaction()?;
            let mut inseridos = 0;

            if let Some(result_sets) = json_box["resultSets"].as_array() {
                if let Some(player_stats) = result_sets.iter().find(|s| s["name"] == "PlayerStats") {
                    let headers = player_stats["headers"].as_array().unwrap();
                    let rows = player_stats["rowSet"].as_array().unwrap();
                    
                    let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);
                    
                    let idx_player_id = achar_idx("PLAYER_ID");
                    let idx_player_name = achar_idx("PLAYER_NAME");
                    let idx_team_abbr = achar_idx("TEAM_ABBREVIATION");
                    let idx_comment = achar_idx("COMMENT");
                    let idx_min = achar_idx("MIN");

                    
                    let mut times_no_jogo: Vec<String> = Vec::new();
                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        if let Some(sigla) = row[idx_team_abbr].as_str() {
                            if !times_no_jogo.contains(&sigla.to_string()) && !sigla.is_empty() {
                                times_no_jogo.push(sigla.to_string());
                            }
                        }
                    }

                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        let comment = row[idx_comment].as_str().unwrap_or("");
                        let min = row[idx_min].as_str().unwrap_or("");

                        if comment.is_empty() && !min.is_empty() {
                            let player_id = row[idx_player_id].as_i64().unwrap_or(0);
                            let player_name = row[idx_player_name].as_str().unwrap_or("");
                            let time_jogador = row[idx_team_abbr].as_str().unwrap_or("");
                            
                            // Define o adversário comparando com o array 'times_no_jogo'
                            let mut time_adversario = "";
                            if times_no_jogo.len() == 2 {
                                time_adversario = if time_jogador == times_no_jogo[0] {
                                    &times_no_jogo[1]
                                } else {
                                    &times_no_jogo[0]
                                };
                            }

                            let pts = row[achar_idx("PTS")].as_i64().unwrap_or(0);
                            let ast = row[achar_idx("AST")].as_i64().unwrap_or(0);
                            let reb = row[achar_idx("REB")].as_i64().unwrap_or(0);
                            let oreb = row[achar_idx("OREB")].as_i64().unwrap_or(0);
                            let dreb = row[achar_idx("DREB")].as_i64().unwrap_or(0);
                            let stl = row[achar_idx("STL")].as_i64().unwrap_or(0);
                            let blk = row[achar_idx("BLK")].as_i64().unwrap_or(0);
                            let tov = row[achar_idx("TO")].as_i64().unwrap_or(0);
                            let pf = row[achar_idx("PF")].as_i64().unwrap_or(0);
                            
                            let fgm = row[achar_idx("FGM")].as_i64().unwrap_or(0);
                            let fga = row[achar_idx("FGA")].as_i64().unwrap_or(0);
                            let fg_pct = row[achar_idx("FG_PCT")].as_f64().unwrap_or(0.0);
                            
                            let fg3m = row[achar_idx("FG3M")].as_i64().unwrap_or(0);
                            let fg3a = row[achar_idx("FG3A")].as_i64().unwrap_or(0);
                            let fg3_pct = row[achar_idx("FG3_PCT")].as_f64().unwrap_or(0.0);
                            
                            let ftm = row[achar_idx("FTM")].as_i64().unwrap_or(0);
                            let fta = row[achar_idx("FTA")].as_i64().unwrap_or(0);
                            let ft_pct = row[achar_idx("FT_PCT")].as_f64().unwrap_or(0.0);
                            
                            let plus_minus = row[achar_idx("PLUS_MINUS")].as_i64().unwrap_or(0);

                            tx.execute(
                                "INSERT INTO stats_partida_individual (
                                    game_id, data_jogo, nba_player_id, nome_completo, 
                                    time_jogador, time_adversario, minutos,
                                    pts, ast, reb, oreb, dreb, stl, blk, tov, pf,
                                    fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, plus_minus
                                ) VALUES (
                                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13,
                                    ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26
                                )
                                ON CONFLICT(game_id, nba_player_id) DO UPDATE SET
                                    minutos = excluded.minutos,
                                    pts = excluded.pts,
                                    ast = excluded.ast,
                                    reb = excluded.reb,
                                    oreb = excluded.oreb,
                                    dreb = excluded.dreb,
                                    stl = excluded.stl,
                                    blk = excluded.blk,
                                    tov = excluded.tov,
                                    pf = excluded.pf,
                                    fgm = excluded.fgm,
                                    fga = excluded.fga,
                                    fg_pct = excluded.fg_pct,
                                    fg3m = excluded.fg3m,
                                    fg3a = excluded.fg3a,
                                    fg3_pct = excluded.fg3_pct,
                                    ftm = excluded.ftm,
                                    fta = excluded.fta,
                                    ft_pct = excluded.ft_pct,
                                    plus_minus = excluded.plus_minus",
                                params![
                                    game_id, data_alvo, player_id, player_name, 
                                    time_jogador, time_adversario, min,
                                    pts, ast, reb, oreb, dreb, stl, blk, tov, pf,
                                    fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, plus_minus
                                ],
                            )?;

                            inseridos += 1; // Simplificado, já que agora sempre insere ou atualiza
                        }
                    }
                }
            }
            tx.commit()?;
            println!("  -> {} linhas salvas. (Jogo {})", inseridos, game_id);
        }
        
        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    println!("Extração finalizada!");
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