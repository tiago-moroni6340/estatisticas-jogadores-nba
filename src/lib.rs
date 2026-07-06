use reqwest::header::{
    HeaderMap, HeaderValue, ACCEPT, ACCEPT_LANGUAGE, HOST, ORIGIN, REFERER, USER_AGENT,
};
use std::error::Error;
use std::time::Duration;
use sqlx::PgPool;
use std::env;

pub fn configurar_cliente_http() -> Result<reqwest::Client, Box<dyn Error>> {
    let mut headers = HeaderMap::new();
    
    // Deixando estritamente o que a API da NBA valida para não gerar conflito com o proxy
    headers.insert(HOST, HeaderValue::from_static("stats.nba.com"));
    headers.insert(USER_AGENT, HeaderValue::from_static("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"));
    headers.insert(ACCEPT, HeaderValue::from_static("application/json, text/plain, */*"));
    headers.insert(ORIGIN, HeaderValue::from_static("https://www.nba.com"));
    headers.insert(REFERER, HeaderValue::from_static("https://www.nba.com/"));
    headers.insert(ACCEPT_LANGUAGE, HeaderValue::from_static("en-US,en;q=0.9"));
    headers.insert("x-nba-stats-origin", HeaderValue::from_static("stats"));
    headers.insert("x-nba-stats-token", HeaderValue::from_static("true"));

    let client_builder = reqwest::Client::builder()
        .timeout(Duration::from_secs(30))
        .default_headers(headers)
        .http1_only(); // Mantém estável para o túnel do Bright Data

    // Injeta o proxy se a variável existir
    let client = if let Ok(proxy_url) = env::var("BRIGHT_DATA_PROXY_URL") {
        let proxy = reqwest::Proxy::all(proxy_url)?;
        client_builder.proxy(proxy).build()?
    } else {
        println!("Aviso: Rodando sem proxy (BRIGHT_DATA_PROXY_URL não definida).");
        client_builder.build()?
    };
    
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
