use reqwest::header::{
    HeaderMap, HeaderValue, ACCEPT, ACCEPT_LANGUAGE, CONNECTION, HOST, ORIGIN, REFERER, USER_AGENT,
};
use std::error::Error;
use std::time::Duration;
use sqlx::PgPool;

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
    headers.insert("x-nba-stats-origin", HeaderValue::from_static("stats"));
    headers.insert("x-nba-stats-token", HeaderValue::from_static("true"));

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(30))
        .default_headers(headers)
        .build()?;
    
    Ok(client)
}

pub async fn criar_tabela_jogadores_ativos(pool: &PgPool) -> Result<(), sqlx::Error> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS jogadores_ativos (
            id SERIAL PRIMARY KEY,
            nba_player_id BIGINT UNIQUE,
            nome_completo TEXT,
            codigo_time BIGINT,
            abreviacao_time TEXT
        )"
    ).execute(pool).await?;
    Ok(())
}

pub async fn criar_tabela_perfil(pool: &PgPool) -> Result<(), sqlx::Error> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS jogadores_perfil (
            id SERIAL PRIMARY KEY,
            nba_player_id BIGINT UNIQUE,
            nome_completo TEXT, data_nascimento TEXT, escola TEXT, pais TEXT, 
            altura TEXT, peso TEXT, posicao TEXT, numero_camisa TEXT, 
            anos_experiencia TEXT, time_atual TEXT
        )"
    ).execute(pool).await?;
    Ok(())
}

pub async fn criar_tabelas_estatisticas(pool: &PgPool) -> Result<(), sqlx::Error> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS stats_temporada_regular (
            id SERIAL PRIMARY KEY,
            nba_player_id BIGINT, season_id TEXT, team_abbreviation TEXT,
            player_age DOUBLE PRECISION, gp BIGINT, gs BIGINT, min BIGINT, pts BIGINT,
            ast BIGINT, fgm BIGINT, fga BIGINT, fg_pct DOUBLE PRECISION, fg3m BIGINT, fg3a BIGINT, 
            fg3_pct DOUBLE PRECISION, ftm BIGINT, fta BIGINT, ft_pct DOUBLE PRECISION,
            oreb BIGINT, dreb BIGINT, reb BIGINT, stl BIGINT, blk BIGINT, tov BIGINT, fp BIGINT,
            UNIQUE(nba_player_id, season_id, team_abbreviation)
        )"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE TABLE IF NOT EXISTS stats_playoffs (
            id SERIAL PRIMARY KEY,
            nba_player_id BIGINT, season_id TEXT, team_abbreviation TEXT,
            player_age DOUBLE PRECISION, gp BIGINT, gs BIGINT, min BIGINT, pts BIGINT,
            ast BIGINT, fgm BIGINT, fga BIGINT, fg_pct DOUBLE PRECISION, fg3m BIGINT, fg3a BIGINT, 
            fg3_pct DOUBLE PRECISION, ftm BIGINT, fta BIGINT, ft_pct DOUBLE PRECISION,
            oreb BIGINT, dreb BIGINT, reb BIGINT, stl BIGINT, blk BIGINT, tov BIGINT, fp BIGINT,
            UNIQUE(nba_player_id, season_id, team_abbreviation)
        )"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE TABLE IF NOT EXISTS totais_carreira_regular (
            id SERIAL PRIMARY KEY,
            nba_player_id BIGINT UNIQUE, gp BIGINT, gs BIGINT, min BIGINT, pts BIGINT,
            ast BIGINT, fgm BIGINT, fga BIGINT, fg_pct DOUBLE PRECISION, fg3m BIGINT, fg3a BIGINT, 
            fg3_pct DOUBLE PRECISION, ftm BIGINT, fta BIGINT, ft_pct DOUBLE PRECISION,
            oreb BIGINT, dreb BIGINT, reb BIGINT, stl BIGINT, blk BIGINT, tov BIGINT, fp BIGINT
        )"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE TABLE IF NOT EXISTS totais_carreira_playoffs (
            id SERIAL PRIMARY KEY,
            nba_player_id BIGINT UNIQUE, gp BIGINT, gs BIGINT, min BIGINT, pts BIGINT,
            ast BIGINT, fgm BIGINT, fga BIGINT, fg_pct DOUBLE PRECISION, fg3m BIGINT, fg3a BIGINT, 
            fg3_pct DOUBLE PRECISION, ftm BIGINT, fta BIGINT, ft_pct DOUBLE PRECISION,
            oreb BIGINT, dreb BIGINT, reb BIGINT, stl BIGINT, blk BIGINT, tov BIGINT, fp BIGINT
        )"
    ).execute(pool).await?;

    Ok(())
}
