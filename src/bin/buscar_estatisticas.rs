use rusqlite::{params, Connection};
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::{Duration, Instant}; 
use std::sync::{Arc, Mutex};
use futures::stream::{self, StreamExt}; 

use nba_stats::{configurar_cliente_http, criar_tabelas_estatisticas};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let inicio_pipeline = Instant::now();
    println!("Iniciando pipeline de ESTATÍSTICAS da NBA...");

    let conn = Connection::open(r"C:\Users\moron\Documents\nba_stats\nba_dados.db")?;
    criar_tabelas_estatisticas(&conn)?;
    
    let conn_compartilhada = Arc::new(Mutex::new(conn));
    let client = Arc::new(configurar_cliente_http()?);

    loop {
        let jogadores: Vec<(i64, String)> = {
            let de_fato_conn = conn_compartilhada.lock().unwrap();
            let mut stmt = de_fato_conn.prepare(
                "SELECT j.nba_player_id, j.nome_completo 
                 FROM jogadores_ativos j
                 LEFT JOIN totais_carreira_regular t ON j.nba_player_id = t.nba_player_id
                 WHERE t.nba_player_id IS NULL
                 LIMIT 10"
            )?;
            stmt.query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?
                .filter_map(Result::ok)
                .collect()
        };

        if jogadores.is_empty() {
            println!("\n[FIM] Todas as estatísticas foram processadas!");
            break;
        }

        println!("\n--- Processando lote de {} estatísticas ---", jogadores.len());
        let limite_concorrencia = 3; 

        let processamento_stream = stream::iter(jogadores).map(|(player_id, nome)| {
            let client = Arc::clone(&client);
            let conn = Arc::clone(&conn_compartilhada);

            async move {
                println!(">>> [Stats] Buscando: {} (ID: {})", nome, player_id);

                let url_stats = "https://stats.nba.com/stats/playercareerstats";
                let mut params_stats = HashMap::new();
                params_stats.insert("LeagueID", "00".to_string());
                params_stats.insert("PerMode", "Totals".to_string());
                params_stats.insert("PlayerID", player_id.to_string());

                if let Ok(resp) = client.get(url_stats).query(&params_stats).send().await {
                    if resp.status().is_success() {
                        if let Ok(json_stats) = resp.json::<Value>().await {
                            let mut de_fato_conn = conn.lock().unwrap();
                            let _ = salvar_estatisticas(&mut de_fato_conn, &json_stats);
                        }
                    }
                }
                tokio::time::sleep(Duration::from_millis(300)).await;
            }
        }).buffer_unordered(limite_concorrencia);

        processamento_stream.collect::<()>().await;

        println!("Aguardando 5 segundos antes do próximo lote...");
        tokio::time::sleep(Duration::from_secs(5)).await;
    }

    println!("\nFim da execução de Estatísticas em {:.2?}", inicio_pipeline.elapsed());
    Ok(())
}

fn salvar_estatisticas(conn: &mut Connection, json: &Value) -> Result<(), Box<dyn Error>> {
    let tx = conn.transaction()?; 

    if let Some(result_sets) = json["resultSets"].as_array() {
        for subset in result_sets {
            let nome_tabela = subset["name"].as_str().unwrap_or("");
            let headers = subset["headers"].as_array();
            let rows = subset["rowSet"].as_array();

            if headers.is_none() || rows.is_none() { continue; }
            let (headers, rows) = (headers.unwrap(), rows.unwrap());
            
            let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);

            match nome_tabela {
                "SeasonTotalsRegularSeason" => {
                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO stats_temporada_regular 
                             (nba_player_id, season_id, team_abbreviation, player_age, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, pf)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25)",
                            params![
                                row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0),
                                row[achar_idx("SEASON_ID")].as_str().unwrap_or(""),
                                row[achar_idx("TEAM_ABBREVIATION")].as_str().unwrap_or(""),
                                row[achar_idx("PLAYER_AGE")].as_f64().unwrap_or(0.0),
                                row[achar_idx("GP")].as_i64().unwrap_or(0),
                                row[achar_idx("GS")].as_i64().unwrap_or(0),
                                row[achar_idx("MIN")].as_i64().unwrap_or(0),
                                row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                row[achar_idx("AST")].as_i64().unwrap_or(0),
                                row[achar_idx("FGM")].as_i64().unwrap_or(0),
                                row[achar_idx("FGA")].as_i64().unwrap_or(0),
                                row[achar_idx("FG_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3M")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3A")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FTM")].as_i64().unwrap_or(0),
                                row[achar_idx("FTA")].as_i64().unwrap_or(0),
                                row[achar_idx("FT_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("OREB")].as_i64().unwrap_or(0),
                                row[achar_idx("DREB")].as_i64().unwrap_or(0),
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                                row[achar_idx("STL")].as_i64().unwrap_or(0),
                                row[achar_idx("BLK")].as_i64().unwrap_or(0),
                                row[achar_idx("TOV")].as_i64().unwrap_or(0),
                                row[achar_idx("PF")].as_i64().unwrap_or(0),
                            ],
                        )?;
                    }
                }
                "SeasonTotalsPostSeason" => {
                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO stats_playoffs 
                             (nba_player_id, season_id, team_abbreviation, player_age, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, pf)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25)",
                            params![
                                row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0),
                                row[achar_idx("SEASON_ID")].as_str().unwrap_or(""),
                                row[achar_idx("TEAM_ABBREVIATION")].as_str().unwrap_or(""),
                                row[achar_idx("PLAYER_AGE")].as_f64().unwrap_or(0.0),
                                row[achar_idx("GP")].as_i64().unwrap_or(0),
                                row[achar_idx("GS")].as_i64().unwrap_or(0),
                                row[achar_idx("MIN")].as_i64().unwrap_or(0),
                                row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                row[achar_idx("AST")].as_i64().unwrap_or(0),
                                row[achar_idx("FGM")].as_i64().unwrap_or(0),
                                row[achar_idx("FGA")].as_i64().unwrap_or(0),
                                row[achar_idx("FG_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3M")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3A")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FTM")].as_i64().unwrap_or(0),
                                row[achar_idx("FTA")].as_i64().unwrap_or(0),
                                row[achar_idx("FT_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("OREB")].as_i64().unwrap_or(0),
                                row[achar_idx("DREB")].as_i64().unwrap_or(0),
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                                row[achar_idx("STL")].as_i64().unwrap_or(0),
                                row[achar_idx("BLK")].as_i64().unwrap_or(0),
                                row[achar_idx("TOV")].as_i64().unwrap_or(0),
                                row[achar_idx("PF")].as_i64().unwrap_or(0),
                            ],
                        )?;
                    }
                }
                "CareerTotalsRegularSeason" => {
                    if let Some(row) = rows.get(0).and_then(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO totais_carreira_regular 
                             (nba_player_id, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, fp)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22)",
                            params![
                                row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0),
                                row[achar_idx("GP")].as_i64().unwrap_or(0),
                                row[achar_idx("GS")].as_i64().unwrap_or(0),
                                row[achar_idx("MIN")].as_i64().unwrap_or(0),
                                row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                row[achar_idx("AST")].as_i64().unwrap_or(0),
                                row[achar_idx("FGM")].as_i64().unwrap_or(0),
                                row[achar_idx("FGA")].as_i64().unwrap_or(0),
                                row[achar_idx("FG_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3M")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3A")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FTM")].as_i64().unwrap_or(0),
                                row[achar_idx("FTA")].as_i64().unwrap_or(0),
                                row[achar_idx("FT_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("OREB")].as_i64().unwrap_or(0),
                                row[achar_idx("DREB")].as_i64().unwrap_or(0),
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                                row[achar_idx("STL")].as_i64().unwrap_or(0),
                                row[achar_idx("BLK")].as_i64().unwrap_or(0),
                                row[achar_idx("TOV")].as_i64().unwrap_or(0),
                                row[achar_idx("PF")].as_i64().unwrap_or(0),
                            ],
                        )?;
                    }
                }
                "CareerTotalsPostSeason" => {
                    if let Some(row) = rows.get(0).and_then(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO totais_carreira_playoffs 
                             (nba_player_id, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, fp)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22)",
                            params![
                                row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0),
                                row[achar_idx("GP")].as_i64().unwrap_or(0),
                                row[achar_idx("GS")].as_i64().unwrap_or(0),
                                row[achar_idx("MIN")].as_i64().unwrap_or(0),
                                row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                row[achar_idx("AST")].as_i64().unwrap_or(0),
                                row[achar_idx("FGM")].as_i64().unwrap_or(0),
                                row[achar_idx("FGA")].as_i64().unwrap_or(0),
                                row[achar_idx("FG_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3M")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3A")].as_i64().unwrap_or(0),
                                row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("FTM")].as_i64().unwrap_or(0),
                                row[achar_idx("FTA")].as_i64().unwrap_or(0),
                                row[achar_idx("FT_PCT")].as_i64().unwrap_or(0),
                                row[achar_idx("OREB")].as_i64().unwrap_or(0),
                                row[achar_idx("DREB")].as_i64().unwrap_or(0),
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                                row[achar_idx("STL")].as_i64().unwrap_or(0),
                                row[achar_idx("BLK")].as_i64().unwrap_or(0),
                                row[achar_idx("TOV")].as_i64().unwrap_or(0),
                                row[achar_idx("PF")].as_i64().unwrap_or(0),
                            ],
                        )?;
                    }
                }
                _ => {}
            }
        }
    }
    tx.commit()?;
    Ok(())
}