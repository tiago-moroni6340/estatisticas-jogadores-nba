use sqlx::postgres::PgPoolOptions;
use std::collections::HashMap;
use std::error::Error;
use std::env;

use nba_stats::{configurar_cliente_http, criar_tabela_jogadores_ativos};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Substitua pela URL do seu banco Postgres na Oracle Cloud
    dotenvy::dotenv().ok();
    
    let db_url = env::var("DATABASE_URL_RUST").expect("A variável de ambiente DATABASE_URL_RUST não foi definida no arquivo .env");

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
        
        println!("Conectando ao banco de dados PostgreSQL...");
        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(db_url)
            .await?;

        criar_tabela_jogadores_ativos(&pool).await?;

        if let Some(result_sets) = json_body.get("resultSets").and_then(|v| v.get(0)) {
            if let Some(row_set) = result_sets.get("rowSet").and_then(|v| v.as_array()) {
                
                println!("Iniciando gravação dos jogadores no banco de dados...");
                
                let mut tx = pool.begin().await?;
                let mut contador_inseridos = 0;

                for row in row_set {
                    let player_id = row.get(0).and_then(|v| v.as_i64()).unwrap_or(0);
                    let display_name = row.get(2).and_then(|v| v.as_str()).unwrap_or("");
                    let roster_status = row.get(3).and_then(|v| v.as_i64()).unwrap_or(0);
                    let team_id = row.get(8).and_then(|v| v.as_i64()).unwrap_or(0);
                    let team_abbreviation = row.get(10).and_then(|v| v.as_str()).unwrap_or("");

                    if roster_status == 1 && player_id != 0 {
                        // Sintaxe de UPSERT do Postgres
                        sqlx::query(
                            "INSERT INTO jogadores_ativos (nba_player_id, nome_completo, codigo_time, abreviacao_time)
                             VALUES ($1, $2, $3, $4)
                             ON CONFLICT (nba_player_id) DO UPDATE SET 
                                nome_completo = EXCLUDED.nome_completo,
                                codigo_time = EXCLUDED.codigo_time,
                                abreviacao_time = EXCLUDED.abreviacao_time"
                        )
                        .bind(player_id)
                        .bind(display_name)
                        .bind(team_id)
                        .bind(team_abbreviation)
                        .execute(&mut *tx)
                        .await?;
                        
                        contador_inseridos += 1;
                    }
                }

                tx.commit().await?;
                println!("Sucesso! {} jogadores ativos salvos.", contador_inseridos);
            }
        }
    } else {
        println!("Erro ao acessar a API: Status {}", response.status());
    }

    Ok(())
}
