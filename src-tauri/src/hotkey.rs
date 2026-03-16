use tauri::AppHandle;
use tauri::Emitter;
use tauri::Manager;
use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};

pub fn register(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    let app_clone = app.clone();

    app.global_shortcut().on_shortcut("ctrl+alt+n", move |_app_handle, _shortcut, event| {
        if event.state == ShortcutState::Pressed {
            let text = crate::clipboard::capture_selection(&app_clone);

            if let Some(w) = app_clone.get_webview_window("popup") {
                let _ = w.show();
                let _ = w.center();
                let _ = w.set_focus();
            }

            match text {
                Some(t) if !t.trim().is_empty() => {
                    let _ = app_clone.emit("hotkey-triggered", serde_json::json!({ "text": t }));
                }
                _ => {
                    let _ = app_clone.emit("hotkey-empty", ());
                }
            }
        }
    })?;

    Ok(())
}
