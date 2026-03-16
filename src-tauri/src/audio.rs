use base64::Engine;
use rodio::{OutputStream, Sink, Source};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tauri::{AppHandle, Emitter, State};

pub enum AudioCommand {
    PlayChunk { samples_b64: String, sample_rate: u32 },
    Pause,
    Resume,
    Stop,
    SetSpeed(f32),
    /// Signal that all chunks have been sent — start watching for sink empty
    MarkSynthesisDone,
}

pub struct AudioState {
    tx: Mutex<mpsc::Sender<AudioCommand>>,
}

impl AudioState {
    pub fn new(app: AppHandle) -> Self {
        let (tx, rx) = mpsc::channel::<AudioCommand>();
        let speed = Arc::new(Mutex::new(1.0f32));
        let speed_for_thread = speed.clone();

        std::thread::spawn(move || {
            let speed_clone = speed_for_thread;
            let (_stream, handle) = match OutputStream::try_default() {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("Failed to initialize audio output: {e}");
                    return;
                }
            };

            let mut sink: Option<Sink> = Sink::try_new(&handle).ok();
            let synthesis_done = Arc::new(AtomicBool::new(false));

            loop {
                // Non-blocking check for commands with a short timeout
                // so we can also poll sink empty state
                let cmd = if synthesis_done.load(Ordering::Relaxed) {
                    // Poll mode: check if sink is empty (playback finished)
                    match rx.recv_timeout(Duration::from_millis(100)) {
                        Ok(cmd) => Some(cmd),
                        Err(mpsc::RecvTimeoutError::Timeout) => {
                            // Check if playback finished
                            if let Some(ref s) = sink {
                                if s.empty() && !s.is_paused() {
                                    synthesis_done.store(false, Ordering::Relaxed);
                                    let _ = app.emit("playback-finished", ());
                                }
                            }
                            continue;
                        }
                        Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    }
                } else {
                    // Blocking mode: wait for next command
                    match rx.recv() {
                        Ok(cmd) => Some(cmd),
                        Err(_) => break,
                    }
                };

                let Some(cmd) = cmd else { continue };

                match cmd {
                    AudioCommand::PlayChunk { samples_b64, sample_rate } => {
                        if sink.is_none() {
                            sink = Sink::try_new(&handle).ok();
                        }
                        if let Some(ref s) = sink {
                            if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(&samples_b64) {
                                let samples: Vec<f32> = bytes
                                    .chunks_exact(4)
                                    .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                                    .collect();
                                let current_speed = *speed_clone.lock().unwrap();
                                let source = rodio::buffer::SamplesBuffer::new(1, sample_rate, samples)
                                    .speed(current_speed);
                                s.append(source);
                                if s.is_paused() {
                                    s.play();
                                }
                            }
                        }
                    }
                    AudioCommand::Pause => {
                        if let Some(ref s) = sink {
                            s.pause();
                        }
                    }
                    AudioCommand::Resume => {
                        if let Some(ref s) = sink {
                            s.play();
                        }
                    }
                    AudioCommand::Stop => {
                        synthesis_done.store(false, Ordering::Relaxed);
                        if let Some(s) = sink.take() {
                            s.stop();
                        }
                        sink = Sink::try_new(&handle).ok();
                        let _ = app.emit("playback-stopped", ());
                    }
                    AudioCommand::SetSpeed(new_speed) => {
                        *speed_clone.lock().unwrap() = new_speed;
                        // Note: speed change only applies to future chunks
                    }
                    AudioCommand::MarkSynthesisDone => {
                        synthesis_done.store(true, Ordering::Relaxed);
                    }
                }
            }
        });

        Self {
            tx: Mutex::new(tx),
        }
    }

    fn send(&self, cmd: AudioCommand) -> Result<(), String> {
        self.tx
            .lock()
            .map_err(|e| e.to_string())?
            .send(cmd)
            .map_err(|e| format!("Audio thread not running: {e}"))
    }
}

#[tauri::command]
pub fn audio_play_chunk(state: State<AudioState>, samples_b64: String, sample_rate: u32) -> Result<(), String> {
    state.send(AudioCommand::PlayChunk { samples_b64, sample_rate })
}

#[tauri::command]
pub fn audio_pause(state: State<AudioState>) -> Result<(), String> {
    state.send(AudioCommand::Pause)
}

#[tauri::command]
pub fn audio_resume(state: State<AudioState>) -> Result<(), String> {
    state.send(AudioCommand::Resume)
}

#[tauri::command]
pub fn audio_stop(state: State<AudioState>) -> Result<(), String> {
    state.send(AudioCommand::Stop)
}

#[tauri::command]
pub fn audio_set_speed(state: State<AudioState>, speed: f32) -> Result<(), String> {
    state.send(AudioCommand::SetSpeed(speed))
}

#[tauri::command]
pub fn audio_mark_done(state: State<AudioState>) -> Result<(), String> {
    state.send(AudioCommand::MarkSynthesisDone)
}
