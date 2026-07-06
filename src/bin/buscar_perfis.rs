use sqlx::postgres::PgPoolOptions;
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::{Duration, Instant}; 
use std::sync::Arc;
use futures::stream::{self, StreamExt}; 
use std::env;

use nba_stats::{configurar_cliente_http, criar_tabela_perfil};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let inicio_pipeline = Instant::now();
    println!("Iniciando pipeline de dados PESSOAIS (Perfis) da NBA...");

   let db_url = env::var("DATABASE_URL_RUST").expect("A variável de ambiente DATABASE_URL_RUST não foi definida no arquivo .env");
    let pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await?;
    
    criar_tabela_perfil(&pool).await?;
    let client = Arc::new(configurar_cliente_http()?);

    loop {
        // Query_as substitui o mapeamento manual do rusqlite
        let jogadores: Vec<(i64, String)> = sqlx::query_as::<_, (i64, String)>(
            "SELECT j.nba_player_id, j.nome_completo 
             FROM jogadores_ativos j
             LEFT JOIN jogadores_perfil p ON j.nba_player_id = p.nba_player_id
             WHERE p.nba_player_id IS NULL
             LIMIT 10"
        )
        .fetch_all(&pool)
        .await?;

        if jogadores.is_empty() {
            println!("\n[FIM] Todos os perfis foram processados!");
            break;
        }

        println!("\n--- Processando lote de {} perfis ---", jogadores.len());
        let limite_concorrencia = 3; 

        let processamento_stream = stream::iter(jogadores).map(|(player_id, nome)| {
            let client = Arc::clone(&client);
            let pool = pool.clone(); // O clone do PgPool é muito barato e projetado para isso

            async move {
                println!(">>> [Perfil] Buscando: {} (ID: {})", nome, player_id);

                let url_perfil = "https://stats.nba.com/stats/commonplayerinfo";
                let mut params_perfil = HashMap::new();
                params_perfil.insert("PlayerID", player_id.to_string());
                
                if let Ok(resp) = client.get(url_perfil).query(&params_perfil).send().await {
                    if resp.status().is_success() {
                        if let Ok(json_perfil) = resp.json::<Value>().await {
                            let _ = salvar_perfil(&pool, player_id, &json_perfil).await;
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

    println!("\nFim da execução de Perfis em {:.2?}", inicio_pipeline.elapsed());
    Ok(())
}

async fn salvar_perfil(pool: &sqlx::PgPool, player_id: i64, json: &Value) -> Result<(), Box<dyn Error>> {
    if let Some(result_sets) = json["resultSets"].as_array() {
        if let Some(set) = result_sets.iter().find(|s| s["name"] == "CommonPlayerInfo") {
            let headers = set["headers"].as_array().ok_or("Sem headers")?;
            let rows = set["rowSet"].as_array().ok_or("Sem rowSet")?;
            let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);

            if let Some(r) = rows.get(0).and_then(|row| row.as_array()) {
                sqlx::query(
                    "INSERT INTO jogadores_perfil (
                        nba_player_id, nome_completo, data_nascimento, escola, pais, 
                        altura, peso, posicao, numero_camisa, anos_experiencia, time_atual
                     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                     ON CONFLICT (nba_player_id) DO UPDATE SET 
                        nome_completo = EXCLUDED.nome_completo, data_nascimento = EXCLUDED.data_nascimento, 
                        escola = EXCLUDED.escola, pais = EXCLUDED.pais, altura = EXCLUDED.altura, 
                        peso = EXCLUDED.peso, posicao = EXCLUDED.posicao, numero_camisa = EXCLUDED.numero_camisa, 
                        anos_experiencia = EXCLUDED.anos_experiencia, time_atual = EXCLUDED.time_atual"
                )
                .bind(player_id)
                .bind(r[achar_idx("DISPLAY_FIRST_LAST")].as_str().unwrap_or(""))
                .bind(r[achar_idx("BIRTHDATE")].as_str().unwrap_or(""))
                .bind(r[achar_idx("SCHOOL")].as_str().unwrap_or(""))
                .bind(r[achar_idx("COUNTRY")].as_str().unwrap_or(""))
                .bind(r[achar_idx("HEIGHT")].as_str().unwrap_or(""))
                .bind(r[achar_idx("WEIGHT")].as_str().unwrap_or(""))
                .bind(r[achar_idx("POSITION")].as_str().unwrap_or(""))
                .bind(r[achar_idx("JERSEY")].as_str().unwrap_or(""))
                .bind(r[achar_idx("SEASON_EXP")].as_str().unwrap_or(""))
                .bind(r[achar_idx("TEAM_ABBREVIATION")].as_str().unwrap_or(""))
                .execute(pool)
                .await?;
                
                println!("    [+] Perfil salvo com sucesso.");
            }
        }
    }
    Ok(())
}
