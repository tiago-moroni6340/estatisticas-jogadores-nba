use serde::Serialize;
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::env;

use nba_stats::configurar_cliente_http;

#[derive(Serialize)]
struct RespostaLinhaDoTempo {
    player_id: i64,
    quantidade_jogos: usize,
    historico: Vec<PlayerGameStatHistorico>,
}

#[derive(Serialize)]
struct PlayerGameStatHistorico {
    game_id: String,
    game_date: String, 
    tipo_temporada: String, 
    matchup: String,
    wl: String,
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
        eprintln!("ERRO: PlayerID não fornecido.");
        eprintln!("Uso correto: {} <PLAYER_ID> [TEMPORADA]", args[0]);
        eprintln!("Exemplo: {} 2544 ou {} 2544 2025-26", args[0], args[0]);
        std::process::exit(1);
    }

    let player_id_str = &args[1];
    let player_id: i64 = player_id_str.parse().expect("Player ID inválido. Deve ser um número.");
    let temporada = if args.len() >= 3 { args[2].as_str() } else { "2025-26" };

    eprintln!("Buscando a linha do tempo dos últimos 10 jogos (Regular + Playoffs) para o PlayerID: {}...", player_id);

    let client = configurar_cliente_http()?;
    
    let (reg_res, play_res) = tokio::join!(
        buscar_gamelog(&client, player_id_str, temporada, "Regular Season"),
        buscar_gamelog(&client, player_id_str, temporada, "Playoffs")
    );

    let mut todos_os_jogos = Vec::new();

    if let Ok(mut jogos_reg) = reg_res {
        todos_os_jogos.append(&mut jogos_reg);
    }
   
    if let Ok(mut jogos_play) = play_res {
        todos_os_jogos.append(&mut jogos_play);
    }

    // Ordenação do mais recente para o mais antigo, combinando Regular e Playoffs
    todos_os_jogos.sort_by(|a, b| b.game_date.cmp(&a.game_date));
    todos_os_jogos.truncate(10);

    let resposta_final = RespostaLinhaDoTempo {
        player_id,
        quantidade_jogos: todos_os_jogos.len(),
        historico: todos_os_jogos,
    };

    let json_output = serde_json::to_string_pretty(&resposta_final)?;
    std::fs::write("linha_tempo_jogador.json", &json_output)?;
    println!("{}", json_output);

    Ok(())
}

async fn buscar_gamelog(
    client: &reqwest::Client,
    player_id: &str,
    temporada: &str,
    tipo_temporada: &str,
) -> Result<Vec<PlayerGameStatHistorico>, Box<dyn Error + Send + Sync>> {
    let url_gamelog = "https://stats.nba.com/stats/playergamelogs";
    
    let mut params = HashMap::new();
    params.insert("PlayerID", player_id);
    params.insert("Season", temporada);
    params.insert("SeasonType", tipo_temporada);
    params.insert("LeagueID", "00");
    params.insert("LastNGames", "10"); 

    let resp = client.get(url_gamelog).query(&params).send().await?;
    let mut lista_jogos = Vec::new();

    if resp.status().is_success() {
        let json_resp: Value = resp.json().await?;
        
        if let Some(result_sets) = json_resp["resultSets"].as_array() {
            if let Some(player_game_logs) = result_sets.iter().find(|s| s["name"] == "PlayerGameLogs") {
                let headers = player_game_logs["headers"].as_array().unwrap();
                let rows = player_game_logs["rowSet"].as_array().unwrap();
                
                let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);
                
                for row in rows.iter().filter_map(|r| r.as_array()) {
                    lista_jogos.push(PlayerGameStatHistorico {
                        game_id: row[achar_idx("GAME_ID")].as_str().unwrap_or("").to_string(),
                        game_date: row[achar_idx("GAME_DATE")].as_str().unwrap_or("").to_string(),
                        tipo_temporada: tipo_temporada.to_string(),
                        matchup: row[achar_idx("MATCHUP")].as_str().unwrap_or("").to_string(),
                        wl: row[achar_idx("WL")].as_str().unwrap_or("").to_string(),
                        minutos: row[achar_idx("MIN")].as_str().unwrap_or("0").to_string(),
                        pts: row[achar_idx("PTS")].as_i64().unwrap_or(0),
                        ast: row[achar_idx("AST")].as_i64().unwrap_or(0),
                        reb: row[achar_idx("REB")].as_i64().unwrap_or(0),
                        oreb: row[achar_idx("OREB")].as_i64().unwrap_or(0),
                        dreb: row[achar_idx("DREB")].as_i64().unwrap_or(0),
                        stl: row[achar_idx("STL")].as_i64().unwrap_or(0),
                        blk: row[achar_idx("BLK")].as_i64().unwrap_or(0),
                        tov: row[achar_idx("TOV")].as_i64().unwrap_or(0),
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

    Ok(lista_jogos)
}