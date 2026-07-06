use rusqlite::{params, Connection};
use serde_json::Value;
use std::collections::HashMap;
use std::error::Error;
use std::time::{Duration, Instant}; 
use std::sync::{Arc, Mutex};
use futures::stream::{self, StreamExt}; 

// Importa as funções compartilhadas da biblioteca do seu projeto
use nba_stats::{configurar_cliente_http, criar_tabela_perfil};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let inicio_pipeline = Instant::now();
    println!("Iniciando pipeline de dados PESSOAIS (Perfis) da NBA...");

    let conn = Connection::open(r"C:\Users\moron\Documents\nba_stats\nba_dados.db")?;
    criar_tabela_perfil(&conn)?;
    
    let conn_compartilhada = Arc::new(Mutex::new(conn));
    let client = Arc::new(configurar_cliente_http()?);

    loop {
        let jogadores: Vec<(i64, String)> = {
            let de_fato_conn = conn_compartilhada.lock().unwrap();
            let mut stmt = de_fato_conn.prepare(
                "SELECT j.nba_player_id, j.nome_completo 
                 FROM jogadores_ativos j
                 LEFT JOIN jogadores_perfil p ON j.nba_player_id = p.nba_player_id
                 WHERE p.nba_player_id IS NULL
                 LIMIT 10"
            )?;
            stmt.query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?
                .filter_map(Result::ok)
                .collect()
        };

        if jogadores.is_empty() {
            println!("\n[FIM] Todos os perfis foram processados!");
            break;
        }

        println!("\n--- Processando lote de {} perfis ---", jogadores.len());
        let limite_concorrencia = 3; 

        let processamento_stream = stream::iter(jogadores).map(|(player_id, nome)| {
            let client = Arc::clone(&client);
            let conn = Arc::clone(&conn_compartilhada);

            async move {
                println!(">>> [Perfil] Buscando: {} (ID: {})", nome, player_id);

                let url_perfil = "https://stats.nba.com/stats/commonplayerinfo";
                let mut params_perfil = HashMap::new();
                params_perfil.insert("PlayerID", player_id.to_string());
                
                if let Ok(resp) = client.get(url_perfil).query(&params_perfil).send().await {
                    if resp.status().is_success() {
                        if let Ok(json_perfil) = resp.json::<Value>().await {
                            let de_fato_conn = conn.lock().unwrap();
                            let _ = salvar_perfil(&de_fato_conn, player_id, &json_perfil);
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

fn salvar_perfil(conn: &Connection, player_id: i64, json: &Value) -> Result<(), Box<dyn Error>> {
    if let Some(result_sets) = json["resultSets"].as_array() {
        if let Some(set) = result_sets.iter().find(|s| s["name"] == "CommonPlayerInfo") {
            let headers = set["headers"].as_array().ok_or("Sem headers")?;
            let rows = set["rowSet"].as_array().ok_or("Sem rowSet")?;
            let achar_idx = |nome: &str| headers.iter().position(|h| h.as_str() == Some(nome)).unwrap_or(0);

            if let Some(r) = rows.get(0).and_then(|row| row.as_array()) {
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
                        r[achar_idx("TEAM_ABBREVIATION")].as_str().unwrap_or("")
                    ],
                )?;
                println!("    [+] Perfil salvo com sucesso.");
            }
        }
    }
    Ok(())
}