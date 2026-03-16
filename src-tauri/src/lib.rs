mod audio;
mod clipboard;
mod hotkey;
mod sidecar;
mod tray;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .manage(sidecar::SidecarState::new())
        .invoke_handler(tauri::generate_handler![
            sidecar::list_voices,
            sidecar::synthesize,
            sidecar::stop_synthesis,
            audio::audio_play_chunk,
            audio::audio_pause,
            audio::audio_resume,
            audio::audio_stop,
            audio::audio_set_speed,
            audio::audio_mark_done,
        ])
        .setup(|app| {
            let handle = app.handle().clone();

            // Initialize audio state (needs AppHandle for events)
            app.manage(audio::AudioState::new(handle.clone()));

            // Setup tray icon
            tray::setup(&handle)?;

            // Register global hotkey (non-fatal — another app may hold it)
            if let Err(e) = hotkey::register(&handle) {
                eprintln!("Warning: Failed to register hotkey: {e}");
            }

            // Start the Python sidecar + warmup model
            if let Err(e) = sidecar::start(&handle) {
                eprintln!("Warning: Failed to start TTS sidecar: {e}");
            }

            Ok(())
        })
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                let _ = window.hide();
                api.prevent_close();
            }
        })
        .build(tauri::generate_context!())
        .expect("error building tauri app")
        .run(|app, event| {
            if let tauri::RunEvent::Exit = event {
                let state: tauri::State<sidecar::SidecarState> = app.state();
                sidecar::shutdown(&state);
            }
        });
}
