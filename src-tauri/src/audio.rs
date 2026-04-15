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
    SkipForward(f32),  // seconds
    SkipBack(f32),     // seconds
    MarkSynthesisDone,
}

pub struct AudioState {
    tx: Mutex<mpsc::Sender<AudioCommand>>,
}

impl AudioState {
    pub fn new(app: AppHandle) -> Self {
        let (tx, rx) = mpsc::channel::<AudioCommand>();

        std::thread::spawn(move || {
            let (_stream, handle) = match OutputStream::try_default() {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("Failed to initialize audio output: {e}");
                    return;
                }
            };

            let mut sink: Option<Sink> = Sink::try_new(&handle).ok();
            let synthesis_done = Arc::new(AtomicBool::new(false));

            // Seekable buffer — stores ALL samples for skip/seek
            let mut buffer: Vec<f32> = Vec::new();
            let mut sample_rate: u32 = 24000;
            let mut play_position: usize = 0; // sample offset where current sink started
            let mut samples_queued: usize = 0; // samples queued to sink since last seek
            let mut speed: f32 = 1.0;

            // Replay from buffer at a given sample position
            let replay_from = |sink: &mut Option<Sink>, handle: &rodio::OutputStreamHandle, buf: &[f32], pos: usize, sr: u32, spd: f32| -> usize {
                // Stop current sink
                if let Some(s) = sink.take() {
                    s.stop();
                }
                // Create fresh sink
                *sink = Sink::try_new(handle).ok();
                if let Some(ref s) = sink {
                    if pos < buf.len() {
                        let remaining = &buf[pos..];
                        let source = rodio::buffer::SamplesBuffer::new(1, sr, remaining.to_vec()).speed(spd);
                        s.append(source);
                    }
                }
                buf.len() - pos.min(buf.len()) // samples queued
            };

            loop {
                let cmd = if synthesis_done.load(Ordering::Relaxed) {
                    match rx.recv_timeout(Duration::from_millis(200)) {
                        Ok(cmd) => Some(cmd),
                        Err(mpsc::RecvTimeoutError::Timeout) => {
                            if let Some(ref s) = sink {
                                if s.empty() && !s.is_paused() {
                                    synthesis_done.store(false, Ordering::Relaxed);
                                    let total_secs = if sample_rate > 0 { buffer.len() as f64 / sample_rate as f64 } else { 0.0 };
                                    let _ = app.emit("playback-finished", serde_json::json!({ "duration": total_secs }));
                                }
                            }
                            continue;
                        }
                        Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    }
                } else {
                    match rx.recv_timeout(Duration::from_millis(500)) {
                        Ok(cmd) => Some(cmd),
                        Err(mpsc::RecvTimeoutError::Timeout) => {
                            // Emit progress
                            if !buffer.is_empty() && sample_rate > 0 {
                                if let Some(ref s) = sink {
                                    if !s.is_paused() && !s.empty() {
                                        // Estimate current position
                                        let elapsed_samples = samples_queued.saturating_sub(
                                            // rodio doesn't expose remaining, so estimate
                                            0 // can't get exact remaining from sink
                                        );
                                        let total = buffer.len() as f64 / sample_rate as f64;
                                        let current = (play_position + elapsed_samples) as f64 / sample_rate as f64;
                                        let _ = app.emit("playback-progress", serde_json::json!({
                                            "current": current.min(total),
                                            "total": total,
                                        }));
                                    }
                                }
                            }
                            continue;
                        }
                        Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    }
                };

                let Some(cmd) = cmd else { continue };

                match cmd {
                    AudioCommand::PlayChunk { samples_b64, sample_rate: sr } => {
                        sample_rate = sr;
                        if sink.is_none() {
                            sink = Sink::try_new(&handle).ok();
                        }
                        if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(&samples_b64) {
                            let samples: Vec<f32> = bytes
                                .chunks_exact(4)
                                .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                                .collect();
                            let chunk_len = samples.len();

                            // Append to buffer
                            buffer.extend_from_slice(&samples);
                            samples_queued += chunk_len;

                            // Play chunk
                            if let Some(ref s) = sink {
                                let source = rodio::buffer::SamplesBuffer::new(1, sr, samples).speed(speed);
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
                        buffer.clear();
                        play_position = 0;
                        samples_queued = 0;
                        let _ = app.emit("playback-stopped", ());
                    }
                    AudioCommand::SetSpeed(new_speed) => {
                        speed = new_speed;
                        // Re-queue from approximate current position with new speed
                        if !buffer.is_empty() {
                            // Estimate where we are (rough — better than nothing)
                            let approx_pos = play_position + (samples_queued / 2);
                            play_position = approx_pos.min(buffer.len());
                            samples_queued = replay_from(&mut sink, &handle, &buffer, play_position, sample_rate, speed);
                        }
                    }
                    AudioCommand::SkipForward(seconds) => {
                        if !buffer.is_empty() && sample_rate > 0 {
                            let skip_samples = (seconds * sample_rate as f32 * speed) as usize;
                            let approx_current = play_position + (samples_queued / 2);
                            play_position = (approx_current + skip_samples).min(buffer.len());
                            samples_queued = replay_from(&mut sink, &handle, &buffer, play_position, sample_rate, speed);
                        }
                    }
                    AudioCommand::SkipBack(seconds) => {
                        if !buffer.is_empty() && sample_rate > 0 {
                            let skip_samples = (seconds * sample_rate as f32 * speed) as usize;
                            let approx_current = play_position + (samples_queued / 2);
                            play_position = approx_current.saturating_sub(skip_samples);
                            samples_queued = replay_from(&mut sink, &handle, &buffer, play_position, sample_rate, speed);
                        }
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
pub fn audio_skip_forward(state: State<AudioState>, seconds: f32) -> Result<(), String> {
    state.send(AudioCommand::SkipForward(seconds))
}

#[tauri::command]
pub fn audio_skip_back(state: State<AudioState>, seconds: f32) -> Result<(), String> {
    state.send(AudioCommand::SkipBack(seconds))
}

#[tauri::command]
pub fn audio_mark_done(state: State<AudioState>) -> Result<(), String> {
    state.send(AudioCommand::MarkSynthesisDone)
}
