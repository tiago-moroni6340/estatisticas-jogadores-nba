use reqwest::header::{
    HeaderMap, HeaderValue, ACCEPT, ACCEPT_LANGUAGE, CONNECTION, HOST, ORIGIN, REFERER, USER_AGENT,
};
use rusqlite::Connection;
use std::error::Error;
use std::time::Duration;

pub fn configurar_cliente_http() -> Result<reqwest::Client, Box<dyn Error>> {
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

pub fn criar_tabela_perfil(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS jogadores_perfil (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER UNIQUE,
            nome_completo TEXT, data_nascimento TEXT, escola TEXT, pais TEXT, 
            altura TEXT, peso TEXT, posicao TEXT, numero_camisa TEXT, 
            anos_experiencia TEXT, time_atual TEXT
        )", [],
    )?;
    Ok(())
}

pub fn criar_tabelas_estatisticas(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS stats_temporada_regular (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER, season_id TEXT, team_abbreviation TEXT,
            player_age REAL, gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER,
            ast INTEGER, reb INTEGER,
            UNIQUE(nba_player_id, season_id, team_abbreviation)
        )", [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS stats_playoffs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER, season_id TEXT, team_abbreviation TEXT,
            player_age REAL, gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER,
            ast INTEGER, reb INTEGER,
            UNIQUE(nba_player_id, season_id, team_abbreviation)
        )", [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS totais_carreira_regular (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER UNIQUE, 
            gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER, ast INTEGER, reb INTEGER
        )", [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS totais_carreira_playoffs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nba_player_id INTEGER UNIQUE, 
            gp INTEGER, gs INTEGER, min INTEGER, pts INTEGER, ast INTEGER, reb INTEGER
        )", [],
    )?;

    Ok(())
}