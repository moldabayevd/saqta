use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::fs;
use regex::Regex;

// ─── Models ──────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "lowercase")]
pub enum RecordingStatus {
    Raw,
    Transcribed,
    Summarized,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Recording {
    pub path: String,
    pub name: String,
    pub date: String,
    pub time: String,
    pub duration_secs: Option<f64>,
    pub size_bytes: u64,
    pub status: RecordingStatus,
    pub transcript_path: Option<String>,
    pub summary_path: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct Config {
    pub recordings_dir: String,
    pub whisper_model: String,
    pub whisper_lang: String,
    pub kk_backend: String,
    pub summarizer_backend: String,
    pub summarizer_model: String,
    pub summarizer_template: String,
}

// ─── Helpers ─────────────────────────────────────────────────────────────

fn home() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".to_string()))
}

/// Путь до bash-скриптов в репозитории saqta.
/// Ищем относительно бинарника, потом по дефолтным путям, потом env.
fn scripts_dir() -> PathBuf {
    if let Ok(env_path) = std::env::var("SAQTA_SCRIPTS_DIR") {
        return PathBuf::from(env_path);
    }

    let candidates = vec![
        home().join("Projects/saqta/scripts"),
        home().join("saqta/scripts"),
        // dev-режим: tauri-app внутри репо
        PathBuf::from("../scripts"),
    ];

    for c in candidates {
        if c.exists() {
            return c.canonicalize().unwrap_or(c);
        }
    }
    PathBuf::from("scripts")
}

/// Минимальный парсер ~/.config/saqta/config.sh — только KEY="value"
/// или KEY=value, без вложенных подстановок.
fn parse_config() -> Config {
    let mut cfg = Config {
        recordings_dir: format!("{}/Recordings", home().display()),
        whisper_model: "ggml-large-v3-turbo.bin".to_string(),
        whisper_lang: "ru".to_string(),
        kk_backend: "qwen3".to_string(),
        summarizer_backend: "ollama".to_string(),
        summarizer_model: "qwen3:32b".to_string(),
        summarizer_template: "protocol".to_string(),
    };

    let path = home().join(".config/saqta/config.sh");
    let Ok(content) = fs::read_to_string(&path) else {
        return cfg;
    };

    let re = Regex::new(r#"(?m)^\s*([A-Z_][A-Z0-9_]*)\s*=\s*"?([^"#\n]*)"?"#).unwrap();
    for cap in re.captures_iter(&content) {
        let key = &cap[1];
        let mut val = cap[2].trim().to_string();
        // Раскрываем $HOME
        val = val.replace("$HOME", &home().display().to_string());
        val = val.replace("${HOME}", &home().display().to_string());

        match key {
            "RECORDINGS_DIR" => cfg.recordings_dir = val,
            "WHISPER_MODEL" => cfg.whisper_model = val,
            "WHISPER_LANG" => cfg.whisper_lang = val,
            "KK_BACKEND" => cfg.kk_backend = val,
            "SUMMARIZER_BACKEND" => cfg.summarizer_backend = val,
            "SUMMARIZER_MODEL" => cfg.summarizer_model = val,
            "SUMMARIZER_TEMPLATE" => cfg.summarizer_template = val,
            _ => {}
        }
    }
    cfg
}

fn duration_via_ffprobe(file: &Path) -> Option<f64> {
    let out = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
        ])
        .arg(file)
        .output()
        .ok()?;
    let s = String::from_utf8_lossy(&out.stdout);
    s.trim().parse::<f64>().ok()
}

fn parse_date_time_from_name(name: &str) -> (String, String) {
    // QuickRecorder: "Recording at 2026-04-22 16.10.00"
    let re = Regex::new(r"(\d{4}-\d{2}-\d{2})\s+(\d{2})[\.:](\d{2})").unwrap();
    if let Some(cap) = re.captures(name) {
        return (
            cap[1].to_string(),
            format!("{}:{}", &cap[2], &cap[3]),
        );
    }
    ("—".to_string(), "—".to_string())
}

fn detect_status_and_paths(file: &Path) -> (RecordingStatus, Option<String>, Option<String>) {
    let stem = file.file_stem().and_then(|s| s.to_str()).unwrap_or("");
    let parent = file.parent().unwrap_or(Path::new(""));

    // Возможные расположения транскрипта
    let candidates = vec![
        parent.join(stem).join(format!("{}.md", stem)),
        parent.join(format!("{}.md", stem)),
    ];

    for transcript in candidates {
        if transcript.exists() {
            let summary = transcript
                .parent()
                .unwrap()
                .join(format!("{}-summary.md", stem));
            if summary.exists() {
                return (
                    RecordingStatus::Summarized,
                    Some(transcript.display().to_string()),
                    Some(summary.display().to_string()),
                );
            }
            return (
                RecordingStatus::Transcribed,
                Some(transcript.display().to_string()),
                None,
            );
        }
    }
    (RecordingStatus::Raw, None, None)
}

// ─── Tauri Commands ──────────────────────────────────────────────────────

#[tauri::command]
fn list_recordings() -> Result<Vec<Recording>, String> {
    let cfg = parse_config();
    let dir = PathBuf::from(&cfg.recordings_dir);
    if !dir.exists() {
        return Ok(vec![]);
    }

    let exts = ["mp4", "mov", "m4a", "wav", "mp3"];
    let mut recordings = vec![];

    for entry in walkdir::WalkDir::new(&dir)
        .max_depth(2)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(ext) = path.extension().and_then(|e| e.to_str()) else {
            continue;
        };
        if !exts.iter().any(|e| e.eq_ignore_ascii_case(ext)) {
            continue;
        }

        let name = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_string();

        let metadata = entry.metadata().map_err(|e| e.to_string())?;
        let size_bytes = metadata.len();
        let (date, time) = parse_date_time_from_name(&name);
        let duration_secs = duration_via_ffprobe(path);
        let (status, transcript_path, summary_path) = detect_status_and_paths(path);

        recordings.push(Recording {
            path: path.display().to_string(),
            name,
            date,
            time,
            duration_secs,
            size_bytes,
            status,
            transcript_path,
            summary_path,
        });
    }

    // Сортируем — самые свежие сверху
    recordings.sort_by(|a, b| {
        let key_a = format!("{} {}", a.date, a.time);
        let key_b = format!("{} {}", b.date, b.time);
        key_b.cmp(&key_a)
    });

    Ok(recordings)
}

#[tauri::command]
fn get_config() -> Result<Config, String> {
    Ok(parse_config())
}

fn run_script(script_name: &str, args: &[&str]) -> Result<String, String> {
    let script = scripts_dir().join(script_name);
    if !script.exists() {
        return Err(format!("Скрипт не найден: {}", script.display()));
    }

    let output = Command::new("bash")
        .arg(&script)
        .args(args)
        .output()
        .map_err(|e| format!("Не удалось запустить bash: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        return Err(format!(
            "Скрипт упал (exit {}):\n{}\n{}",
            output.status.code().unwrap_or(-1),
            stderr,
            stdout
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

#[tauri::command]
fn transcribe(file_path: String) -> Result<String, String> {
    run_script("transcribe-auto.sh", &[&file_path])
}

#[tauri::command]
fn summarize(md_path: String, template: String) -> Result<String, String> {
    let tmpl = if template.is_empty() {
        "protocol".to_string()
    } else {
        template
    };
    run_script(
        "summarize.sh",
        &[&md_path, "--template", &tmpl],
    )
}

#[tauri::command]
fn export_file(md_path: String, format: String) -> Result<String, String> {
    run_script("export.sh", &[&md_path, "--format", &format])
}

#[tauri::command]
fn open_in_finder(path: String) -> Result<(), String> {
    Command::new("open")
        .args(["-R", &path])
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

// ─── Entry point ─────────────────────────────────────────────────────────

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .invoke_handler(tauri::generate_handler![
            list_recordings,
            get_config,
            transcribe,
            summarize,
            export_file,
            open_in_finder,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
