use rusqlite::{params, Connection};
use std::collections::HashMap;
use std::error::Error;

use nba_stats::{configurar_cliente_http, criar_tabela_jogadores_ativos};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let url = "https://stats.nba.com/stats/commonallplayers";

    let mut params_api = HashMap::new();
    params_api.insert("LeagueID", "00");
    params_api.insert("Season", "2025-26");
    params_api.insert("IsOnlyCurrentSeason", "1");

    let client = configurar_cliente_http()?;

    println!("Buscando jogadores ativos na temporada 2025-26...");

    let response = client
        .get(url)
        .query(&params_api)
        .send()
        .await?;

    if response.status().is_success() {
        let json_body: serde_json::Value = response.json().await?;
        
        println!("Conectando ao banco de dados SQLite...");
        let mut conn = Connection::open(r"C:\Users\moron\Documents\nba_stats\nba_dados.db")?;

        criar_tabela_jogadores_ativos(&conn)?;

        if let Some(result_sets) = json_body.get("resultSets").and_then(|v| v.get(0)) {
            if let Some(row_set) = result_sets.get("rowSet").and_then(|v| v.as_array()) {
                
                println!("Iniciando gravação dos jogadores no banco de dados...");
                
                let tx = conn.transaction()?;
                let mut contador_inseridos = 0;

                for row in row_set {
                    let player_id = row.get(0).and_then(|v| v.as_i64()).unwrap_or(0);
                    let display_name = row.get(2).and_then(|v| v.as_str()).unwrap_or("");
                    let roster_status = row.get(3).and_then(|v| v.as_i64()).unwrap_or(0);
                    let team_id = row.get(8).and_then(|v| v.as_i64()).unwrap_or(0);
                    let team_abbreviation = row.get(10).and_then(|v| v.as_str()).unwrap_or("");

                    if roster_status == 1 && player_id != 0 {
                        tx.execute(
                            "INSERT OR REPLACE INTO jogadores_ativos (nba_player_id, nome_completo, codigo_time, abreviacao_time)
                             VALUES (?1, ?2, ?3, ?4)",
                            params![player_id, display_name, team_id, team_abbreviation],
                        )?;
                        contador_inseridos += 1;
                    }
                }

                tx.commit()?;
                println!("Sucesso! {} jogadores ativos salvos.", contador_inseridos);
            }
        }
    } else {
        println!("Erro ao acessar a API: Status {}", response.status());
    }

    Ok(())
}