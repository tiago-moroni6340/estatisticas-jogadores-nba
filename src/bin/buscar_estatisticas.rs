
use sqlx::postgres::PgPoolOptions;
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::{Duration, Instant}; 
use std::sync::Arc;
use futures::stream::{self, StreamExt}; 
use std::env;

use nba_stats::{configurar_cliente_http, criar_tabelas_estatisticas};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    dotenvy::dotenv().ok();
    
    let inicio_pipeline = Instant::now();
    println!("Iniciando pipeline de ESTATÍSTICAS da NBA...");

    let db_url = env::var("DATABASE_URL").expect("A variável de ambiente DATABASE_URL não foi definida no arquivo .env");
    let pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await?;
    
    criar_tabelas_estatisticas(&pool).await?;
    
    let client = Arc::new(configurar_cliente_http()?);

    loop {
        let jogadores: Vec<(i32, String)> = sqlx::query_as::<_, (i32, String)>(
            "SELECT j.nba_player_id, j.nome_completo 
             FROM jogadores_perfil j
             LEFT JOIN totais_carreira_regular t ON j.nba_player_id = t.nba_player_id
             WHERE t.nba_player_id IS NULL
             LIMIT 10"
        )
        .fetch_all(&pool)
        .await?;

        if jogadores.is_empty() {
            println!("\n[FIM] Todas as estatísticas foram processadas!");
            break;
        }

        println!("\n--- Processando lote de {} estatísticas ---", jogadores.len());
        let limite_concorrencia = 3; 

        let processamento_stream = stream::iter(jogadores).map(|(player_id, nome)| {
            let client = Arc::clone(&client);
            let pool = pool.clone();

            async move {
                println!(">>> [Stats] Buscando: {} (ID: {})", nome, player_id);

                let url_stats = "https://stats.nba.com/stats/playercareerstats";
                let mut params_stats = HashMap::new();
                params_stats.insert("LeagueID", "00".to_string());
                params_stats.insert("PerMode", "Totals".to_string());
                params_stats.insert("PlayerID", player_id.to_string());

                match client.get(url_stats).query(&params_stats).send().await {
                    Ok(resp) => {
                        let status = resp.status();
                        
                        if status.is_success() {
                            match resp.json::<Value>().await {
                                Ok(json_stats) => {
                                    if let Err(e) = salvar_estatisticas(&pool, &json_stats).await {
                                        eprintln!(">>> [Erro DB] Falha ao salvar banco para {}: {}", nome, e);
                                    } else {
                                        println!(">>> [Sucesso] Salvo: {}", nome);
                                    }
                                }
                                Err(e) => eprintln!(">>> [Erro JSON] Falha de conversão para {}: {}", nome, e),
                            }
                        } else if status.as_u16() == 429 {
                            eprintln!(">>> [429 Rate Limit] Limite estourado buscando {}!", nome);
                        } else if status.as_u16() == 403 {
                            eprintln!(">>> [403 Forbidden] IP bloqueado pela NBA buscando {}!", nome);
                        } else {
                            eprintln!(">>> [Erro HTTP {}] Falha ao buscar {}", status.as_u16(), nome);
                        }
                    }
                    Err(e) => {
                        eprintln!(">>> [Erro Network] Falha de conexão com o proxy/API para {}: {}", nome, e);
                    }
                }
                
                tokio::time::sleep(Duration::from_millis(500)).await;
            }
        }).buffer_unordered(limite_concorrencia);

        processamento_stream.collect::<()>().await;

        println!("Aguardando 5 segundos antes do próximo lote...");
        tokio::time::sleep(Duration::from_secs(5)).await;
    }

    println!("\nFim da execução de Estatísticas em {:.2?}", inicio_pipeline.elapsed());
    Ok(())
}

async fn salvar_estatisticas(pool: &sqlx::PgPool, json: &Value) -> Result<(), Box<dyn Error>> {
    let mut tx = pool.begin().await?; 
    
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
                        sqlx::query(
                            "INSERT INTO stats_temporada_regular 
                             (nba_player_id, season_id, team_abbreviation, player_age, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, fp)
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25)
                             ON CONFLICT (nba_player_id, season_id, team_abbreviation) DO UPDATE SET 
                             player_age = EXCLUDED.player_age, gp = EXCLUDED.gp, gs = EXCLUDED.gs, min = EXCLUDED.min, pts = EXCLUDED.pts, ast = EXCLUDED.ast, fgm = EXCLUDED.fgm, fga = EXCLUDED.fga, fg_pct = EXCLUDED.fg_pct, fg3m = EXCLUDED.fg3m, fg3a = EXCLUDED.fg3a, fg3_pct = EXCLUDED.fg3_pct, ftm = EXCLUDED.ftm, fta = EXCLUDED.fta, ft_pct = EXCLUDED.ft_pct, oreb = EXCLUDED.oreb, dreb = EXCLUDED.dreb, reb = EXCLUDED.reb, stl = EXCLUDED.stl, blk = EXCLUDED.blk, tov = EXCLUDED.tov, fp = EXCLUDED.fp"
                        )
                        .bind(row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("SEASON_ID")].as_str().unwrap_or(""))
                        .bind(row[achar_idx("TEAM_ABBREVIATION")].as_str().unwrap_or(""))
                        .bind(row[achar_idx("PLAYER_AGE")].as_f64().unwrap_or(0.0))
                        .bind(row[achar_idx("GP")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("GS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("MIN")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PTS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("AST")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3M")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3A")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FT_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("OREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("DREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("REB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("STL")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("BLK")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("TOV")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PF")].as_i64().unwrap_or(0))
                        .execute(&mut *tx).await?;
                    }
                }
                "CareerTotalsRegularSeason" => {
                    if let Some(row) = rows.get(0).and_then(|r| r.as_array()) {
                        sqlx::query(
                            "INSERT INTO totais_carreira_regular 
                             (nba_player_id, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, fp)
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22)
                             ON CONFLICT (nba_player_id) DO UPDATE SET gp = EXCLUDED.gp, gs = EXCLUDED.gs, min = EXCLUDED.min, pts = EXCLUDED.pts, ast = EXCLUDED.ast, fgm = EXCLUDED.fgm, fga = EXCLUDED.fga, fg_pct = EXCLUDED.fg_pct, fg3m = EXCLUDED.fg3m, fg3a = EXCLUDED.fg3a, fg3_pct = EXCLUDED.fg3_pct, ftm = EXCLUDED.ftm, fta = EXCLUDED.fta, ft_pct = EXCLUDED.ft_pct, oreb = EXCLUDED.oreb, dreb = EXCLUDED.dreb, reb = EXCLUDED.reb, stl = EXCLUDED.stl, blk = EXCLUDED.blk, tov = EXCLUDED.tov, fp = EXCLUDED.fp"
                        )
                        .bind(row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("GP")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("GS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("MIN")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PTS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("AST")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3M")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3A")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FT_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("OREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("DREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("REB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("STL")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("BLK")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("TOV")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PF")].as_i64().unwrap_or(0))
                        .execute(&mut *tx).await?;
                    }
                }
                "SeasonTotalsPostSeason" => {
                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        sqlx::query(
                            "INSERT INTO stats_playoffs
                             (nba_player_id, season_id, team_abbreviation, player_age, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, fp)
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25)
                             ON CONFLICT (nba_player_id, season_id, team_abbreviation) DO UPDATE SET 
                             player_age = EXCLUDED.player_age, gp = EXCLUDED.gp, gs = EXCLUDED.gs, min = EXCLUDED.min, pts = EXCLUDED.pts, ast = EXCLUDED.ast, fgm = EXCLUDED.fgm, fga = EXCLUDED.fga, fg_pct = EXCLUDED.fg_pct, fg3m = EXCLUDED.fg3m, fg3a = EXCLUDED.fg3a, fg3_pct = EXCLUDED.fg3_pct, ftm = EXCLUDED.ftm, fta = EXCLUDED.fta, ft_pct = EXCLUDED.ft_pct, oreb = EXCLUDED.oreb, dreb = EXCLUDED.dreb, reb = EXCLUDED.reb, stl = EXCLUDED.stl, blk = EXCLUDED.blk, tov = EXCLUDED.tov, fp = EXCLUDED.fp"
                        )
                        .bind(row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("SEASON_ID")].as_str().unwrap_or(""))
                        .bind(row[achar_idx("TEAM_ABBREVIATION")].as_str().unwrap_or(""))
                        .bind(row[achar_idx("PLAYER_AGE")].as_f64().unwrap_or(0.0))
                        .bind(row[achar_idx("GP")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("GS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("MIN")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PTS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("AST")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3M")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3A")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FT_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("OREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("DREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("REB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("STL")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("BLK")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("TOV")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PF")].as_i64().unwrap_or(0))
                        .execute(&mut *tx).await?;
                    }
                }
                "CareerTotalsPostSeason" => {
                    if let Some(row) = rows.get(0).and_then(|r| r.as_array()) {
                        sqlx::query(
                            "INSERT INTO totais_carreira_playoffs
                             (nba_player_id, gp, gs, min, pts, ast, fgm, fga, fg_pct, fg3m, fg3a, fg3_pct, ftm, fta, ft_pct, oreb, dreb, reb, stl, blk, tov, fp)
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22)
                             ON CONFLICT (nba_player_id) DO UPDATE SET gp = EXCLUDED.gp, gs = EXCLUDED.gs, min = EXCLUDED.min, pts = EXCLUDED.pts, ast = EXCLUDED.ast, fgm = EXCLUDED.fgm, fga = EXCLUDED.fga, fg_pct = EXCLUDED.fg_pct, fg3m = EXCLUDED.fg3m, fg3a = EXCLUDED.fg3a, fg3_pct = EXCLUDED.fg3_pct, ftm = EXCLUDED.ftm, fta = EXCLUDED.fta, ft_pct = EXCLUDED.ft_pct, oreb = EXCLUDED.oreb, dreb = EXCLUDED.dreb, reb = EXCLUDED.reb, stl = EXCLUDED.stl, blk = EXCLUDED.blk, tov = EXCLUDED.tov, fp = EXCLUDED.fp"
                        )
                        .bind(row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("GP")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("GS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("MIN")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PTS")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("AST")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FGA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3M")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3A")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FG3_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTM")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FTA")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("FT_PCT")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("OREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("DREB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("REB")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("STL")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("BLK")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("TOV")].as_i64().unwrap_or(0))
                        .bind(row[achar_idx("PF")].as_i64().unwrap_or(0))
                        .execute(&mut *tx).await?;
                    }
                }
                _ => {}
            }
        }
    }
    tx.commit().await?;
    Ok(())
}
