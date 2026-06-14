use reqwest::header::{
    HeaderMap, HeaderValue, ACCEPT, ACCEPT_LANGUAGE, CONNECTION, HOST, ORIGIN, REFERER, USER_AGENT,
};
use rusqlite::{params, Connection};
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::Duration;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    println!("Iniciando pipeline de extração de dados da NBA...");

    let mut conn = Connection::open(r"C:\Users\moron\Documents\nba_stats\nba_dados.db")?;
    criar_tabelas(&conn)?;
    let client = configurar_cliente_http()?;

    // Buscando o ID correto baseado na nossa alteração anterior
    let jogadores: Vec<(i64, String)> = {
        let mut stmt = conn.prepare("SELECT nba_player_id, nome_completo FROM jogadores_ativos LIMIT 10")?;
        stmt.query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?
            .filter_map(Result::ok)
            .collect()
    };

    if jogadores.is_empty() {
        println!("Nenhum jogador encontrado na tabela 'jogadores_ativos'. Rode o script 'buscar_jogadores' primeiro!");
        return Ok(());
    }

    println!("Encontrados {} jogadores para processar.\n", jogadores.len());

    for (player_id, nome) in jogadores {
        println!(">>> Processando jogador: {} (ID: {})", nome, player_id);

        // --- A. EXTRAIR PERFIL ---
        let url_perfil = "https://stats.nba.com/stats/commonplayerinfo";
        let mut params_perfil = HashMap::new();
        params_perfil.insert("PlayerID", player_id.to_string());
        
        match client.get(url_perfil).query(&params_perfil).send().await {
            Ok(resp) if resp.status().is_success() => {
                let json_perfil: Value = resp.json().await?;
                salvar_perfil(&conn, player_id, &json_perfil)?;
            }
            _ => println!("    [Erro] Falha ao buscar perfil de {}.", nome),
        }

        // --- B. EXTRAIR ESTATÍSTICAS ---
        let url_stats = "https://stats.nba.com/stats/playercareerstats";
        let mut params_stats = HashMap::new();
        params_stats.insert("LeagueID", "00".to_string());
        params_stats.insert("PerMode", "Totals".to_string());
        params_stats.insert("PlayerID", player_id.to_string());

        match client.get(url_stats).query(&params_stats).send().await {
            Ok(resp) if resp.status().is_success() => {
                let json_stats: Value = resp.json().await?;
                salvar_estatisticas(&mut conn, &json_stats)?;
            }
            _ => println!("    [Erro] Falha ao buscar estatísticas de {}.", nome),
        }

        println!("    Aguardando 2 segundos para não sobrecarregar a API...\n");
        tokio::time::sleep(Duration::from_secs(2)).await;
    }

    println!("Pipeline concluída com sucesso! Verifique o banco de dados.");
    Ok(())
}

fn configurar_cliente_http() -> Result<reqwest::Client, Box<dyn Error>> {
    let mut headers = HeaderMap::new();
    headers.insert(HOST, HeaderValue::from_static("stats.nba.com"));
    headers.insert(CONNECTION, HeaderValue::from_static("keep-alive"));
    headers.insert(
        USER_AGENT,
        HeaderValue::from_static("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
    );
    headers.insert(ACCEPT, HeaderValue::from_static("application/json, text/plain, */*"));
    headers.insert(ORIGIN, HeaderValue::from_static("https://www.nba.com"));
    headers.insert(REFERER, HeaderValue::from_static("https://www.nba.com/"));
    headers.insert(ACCEPT_LANGUAGE, HeaderValue::from_static("en-US,en;q=0.9,pt-BR;q=0.8,pt;q=0.7"));
    headers.insert("sec-fetch-site", HeaderValue::from_static("same-site"));
    headers.insert("sec-fetch-mode", HeaderValue::from_static("cors"));
    headers.insert("sec-fetch-dest", HeaderValue::from_static("empty"));

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(15))
        .default_headers(headers)
        .build()?;
    
    Ok(client)
}

fn criar_tabelas(conn: &Connection) -> Result<(), rusqlite::Error> {
    // 1. Tabela de Perfil - id autoincremento + nba_player_id único
    conn.execute(
        "CREATE TABLE IF NOT EXISTS jogadores_perfil (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER UNIQUE,
            nome_completo TEXT, data_nascimento TEXT, escola TEXT, pais TEXT, 
            altura TEXT, peso TEXT, posicao TEXT, numero_camisa TEXT, 
            anos_experiencia TEXT, time_atual TEXT
        )", [],
    )?;

    // 2. Temporada Regular - Chave composta UNIQUE para evitar duplicar a mesma temporada do jogador
    conn.execute(
        "CREATE TABLE IF NOT EXISTS stats_temporada_regular (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER, season_id TEXT, team_abbreviation TEXT,
            player_age REAL, gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER,
            ast INTEGER, reb INTEGER,
            UNIQUE(nba_player_id, season_id, team_abbreviation)
        )", [],
    )?;

    // 3. Playoffs - Chave composta UNIQUE para a mesma temporada do jogador nos playoffs
    conn.execute(
        "CREATE TABLE IF NOT EXISTS stats_playoffs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER, season_id TEXT, team_abbreviation TEXT,
            player_age REAL, gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER,
            ast INTEGER, reb INTEGER,
            UNIQUE(nba_player_id, season_id, team_abbreviation)
        )", [],
    )?;

    // 4. Totais Carreira Regular - id autoincremento + nba_player_id único
    conn.execute(
        "CREATE TABLE IF NOT EXISTS totais_carreira_regular (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER UNIQUE, 
            gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER, ast INTEGER, reb INTEGER
        )", [],
    )?;

    // 5. Totais Carreira Playoffs - id autoincremento + nba_player_id único
    conn.execute(
        "CREATE TABLE IF NOT EXISTS totais_carreira_playoffs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER UNIQUE, 
            gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER, ast INTEGER, reb INTEGER
        )", [],
    )?;

    Ok(())
}

fn salvar_perfil(conn: &Connection, player_id: i64, json: &Value) -> Result<(), Box<dyn Error>> {
    if let Some(result_sets) = json["resultSets"].as_array() {
        if let Some(set) = result_sets.iter().find(|s| s["name"] == "CommonPlayerInfo") {
            let headers = set["headers"].as_array().ok_or("Sem headers")?;
            let rows = set["rowSet"].as_array().ok_or("Sem rowSet")?;
            let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);

            if let Some(r) = rows.get(0).and_then(|row| row.as_array()) {
                // Removido o campo 'id' do INSERT para o SQLite gerar sozinho
                conn.execute(
                    "INSERT OR REPLACE INTO jogadores_perfil (
                        nba_player_id, nome_completo, data_nascimento, escola, pais, 
                        altura, peso, posicao, numero_camisa, anos_experiencia, time_atual
                     ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                    params![
                        player_id,
                        r[achar_idx("DISPLAY_FIRST_LAST")].as_str().unwrap_or(""),
                        r[achar_idx("BIRTHDATE")].as_str().unwrap_or(""),
                        r[achar_idx("SCHOOL")].as_str().unwrap_or(""),
                        r[achar_idx("COUNTRY")].as_str().unwrap_or(""),
                        r[achar_idx("HEIGHT")].as_str().unwrap_or(""),
                        r[achar_idx("WEIGHT")].as_str().unwrap_or(""),
                        r[achar_idx("POSITION")].as_str().unwrap_or(""),
                        r[achar_idx("JERSEY")].as_str().unwrap_or(""),
                        r[achar_idx("SEASON_EXP")].as_str().unwrap_or(""),
                        r[achar_idx("TEAM_NAME")].as_str().unwrap_or("")
                    ],
                )?;
                println!("    [+] Perfil salvo com sucesso.");
            }
        }
    }
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
                             (nba_player_id, season_id, team_abbreviation, player_age, gp, gs, min, pts, ast, reb)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
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
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                            ],
                        )?;
                    }
                    println!("    [+] Stats da Temporada Regular salvas.");
                }
                "SeasonTotalsPostSeason" => {
                    for row in rows.iter().filter_map(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO stats_playoffs 
                             (nba_player_id, season_id, team_abbreviation, player_age, gp, gs, min, pts, ast, reb)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
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
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                            ],
                        )?;
                    }
                    println!("    [+] Stats da Temporada de Playoffs salvas.");
                }
                "CareerTotalsRegularSeason" => {
                    if let Some(row) = rows.get(0).and_then(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO totais_carreira_regular 
                             (nba_player_id, gp, gs, min, pts, ast, reb)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                            params![
                                row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0),
                                row[achar_idx("GP")].as_i64().unwrap_or(0),
                                row[achar_idx("GS")].as_i64().unwrap_or(0),
                                row[achar_idx("MIN")].as_i64().unwrap_or(0),
                                row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                row[achar_idx("AST")].as_i64().unwrap_or(0),
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                            ],
                        )?;
                        println!("    [+] Totais da Carreira (Regular) salvas.");
                    }
                }
                "CareerTotalsPostSeason" => {
                    if let Some(row) = rows.get(0).and_then(|r| r.as_array()) {
                        tx.execute(
                            "INSERT OR REPLACE INTO totais_carreira_playoffs 
                             (nba_player_id, gp, gs, min, pts, ast, reb)
                             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                            params![
                                row[achar_idx("PLAYER_ID")].as_i64().unwrap_or(0),
                                row[achar_idx("GP")].as_i64().unwrap_or(0),
                                row[achar_idx("GS")].as_i64().unwrap_or(0),
                                row[achar_idx("MIN")].as_i64().unwrap_or(0),
                                row[achar_idx("PTS")].as_i64().unwrap_or(0),
                                row[achar_idx("AST")].as_i64().unwrap_or(0),
                                row[achar_idx("REB")].as_i64().unwrap_or(0),
                            ],
                        )?;
                        println!("    [+] Totais da Carreira (Playoffs) salvas.");
                    }
                }
                _ => {}
            }
        }
    }
    tx.commit()?;
    Ok(())
}