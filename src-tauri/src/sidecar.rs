use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter, Manager, State};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Voice {
    pub id: String,
    pub name: String,
    pub group: String,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
#[serde(rename_all = "snake_case")]
enum SidecarResponse {
    Voices { voices: Vec<Voice> },
    Chunk { samples: String, sr: u32 },
    Done { total_chunks: u32 },
    Stopped,
    Ready,
    Error { message: String },
}

/// Commands sent from Tauri to the sidecar IO thread.
enum SidecarCommand {
    Synthesize { text: String, voice: String, speed: f64 },
    Stop,
    ListVoices,
}

pub struct SidecarState {
    tx: Mutex<Option<mpsc::Sender<SidecarCommand>>>,
}

impl SidecarState {
    pub fn new() -> Self {
        Self {
            tx: Mutex::new(None),
        }
    }

    fn send(&self, cmd: SidecarCommand) -> Result<(), String> {
        let guard = self.tx.lock().map_err(|e: std::sync::PoisonError<_>| e.to_string())?;
        let tx = guard.as_ref().ok_or("Sidecar not running")?;
        tx.send(cmd).map_err(|e| format!("Sidecar thread dead: {e}"))
    }
}

/// Start the Python sidecar process and its IO thread.
pub fn start(app: &AppHandle) -> Result<(), String> {
    let state: State<SidecarState> = app.state();
    {
        let guard = state.tx.lock().map_err(|e: std::sync::PoisonError<_>| e.to_string())?;
        if guard.is_some() {
            return Ok(()); // already running
        }
    }

    // Resolve paths
    let script_path = std::env::current_dir()
        .unwrap_or_default()
        .join("../sidecar/tts_server.py");

    let venv_python = std::path::PathBuf::from("C:/Users/12895/tts-studio/.venv/Scripts/python.exe");
    let python = if venv_python.exists() {
        venv_python
    } else {
        std::path::PathBuf::from("python")
    };

    let mut cmd = Command::new(&python);
    cmd.arg(&script_path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    #[cfg(windows)]
    cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW

    let mut child = cmd.spawn()
        .map_err(|e| format!("Failed to start sidecar: {e}"))?;

    let mut stdin = child.stdin.take().ok_or("No stdin")?;
    let stdout = child.stdout.take().ok_or("No stdout")?;

    let (tx, rx) = mpsc::channel::<SidecarCommand>();
    let app_handle = app.clone();

    // Writer thread — sends commands to sidecar stdin
    std::thread::spawn(move || {
        for cmd in rx {
            let json = match &cmd {
                SidecarCommand::Synthesize { text, voice, speed } => {
                    serde_json::json!({ "cmd": "synthesize", "text": text, "voice": voice, "speed": speed })
                }
                SidecarCommand::Stop => serde_json::json!({ "cmd": "stop" }),
                SidecarCommand::ListVoices => serde_json::json!({ "cmd": "list_voices" }),
            };
            let mut line = serde_json::to_string(&json).unwrap();
            line.push('\n');
            if stdin.write_all(line.as_bytes()).is_err() || stdin.flush().is_err() {
                break;
            }
        }
    });

    // Reader thread — reads responses from sidecar stdout, emits events
    let app_reader = app_handle.clone();
    std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line_result in reader.lines() {
            let line = match line_result {
                Ok(l) => l,
                Err(_) => break,
            };
            if line.trim().is_empty() {
                continue;
            }
            let resp: SidecarResponse = match serde_json::from_str(&line) {
                Ok(r) => r,
                Err(e) => {
                    eprintln!("Sidecar parse error: {e} — line: {line}");
                    continue;
                }
            };
            match resp {
                SidecarResponse::Chunk { samples, sr } => {
                    let _ = app_reader.emit("audio-chunk", serde_json::json!({ "samples": samples, "sr": sr }));
                }
                SidecarResponse::Done { total_chunks } => {
                    let _ = app_reader.emit("synthesis-done", serde_json::json!({ "total_chunks": total_chunks }));
                }
                SidecarResponse::Voices { voices } => {
                    let _ = app_reader.emit("voices-loaded", serde_json::json!({ "voices": voices }));
                }
                SidecarResponse::Ready => {
                    let _ = app_reader.emit("sidecar-ready", ());
                }
                SidecarResponse::Stopped => {
                    let _ = app_reader.emit("synthesis-stopped", ());
                }
                SidecarResponse::Error { message } => {
                    let _ = app_reader.emit("sidecar-error", serde_json::json!({ "message": message }));
                    eprintln!("Sidecar error: {message}");
                }
            }
        }
        // Sidecar process ended
        let _ = child.wait();
    });

    // Store the sender
    {
        let mut guard = state.tx.lock().map_err(|e| e.to_string())?;
        *guard = Some(tx);
    }

    // Send warmup command immediately so model loads in background
    state.send(SidecarCommand::Synthesize {
        text: "ready".into(),
        voice: "af_sky".into(),
        speed: 1.0,
    }).ok();

    Ok(())
}

#[tauri::command]
pub fn list_voices(state: State<SidecarState>) -> Result<(), String> {
    state.send(SidecarCommand::ListVoices)
}

#[tauri::command]
pub fn synthesize(
    state: State<SidecarState>,
    text: String,
    voice: String,
    speed: f64,
) -> Result<(), String> {
    state.send(SidecarCommand::Synthesize { text, voice, speed })
}

#[tauri::command]
pub fn stop_synthesis(state: State<SidecarState>) -> Result<(), String> {
    state.send(SidecarCommand::Stop)
}

/// Kill the sidecar process on app exit.
pub fn shutdown(state: &SidecarState) {
    if let Ok(mut guard) = state.tx.lock() {
        let _ = guard.take(); // drop sender, writer thread exits, stdin closes, python exits
    }
}
