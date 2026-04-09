use tauri::{
    menu::{CheckMenuItem, Menu, MenuItem, Submenu},
    tray::TrayIconBuilder,
    AppHandle, Emitter,
};

// Voice definitions — must match sidecar VOICES
const VOICES: &[(&str, &str, &str)] = &[
    // American Female
    ("af_alloy", "Alloy", "American Female"),
    ("af_bella", "Bella", "American Female"),
    ("af_heart", "Heart", "American Female"),
    ("af_jessica", "Jessica", "American Female"),
    ("af_nicole", "Nicole", "American Female"),
    ("af_nova", "Nova", "American Female"),
    ("af_river", "River", "American Female"),
    ("af_sarah", "Sarah", "American Female"),
    ("af_sky", "Sky", "American Female"),
    // American Male
    ("am_adam", "Adam", "American Male"),
    ("am_echo", "Echo", "American Male"),
    ("am_eric", "Eric", "American Male"),
    ("am_liam", "Liam", "American Male"),
    ("am_michael", "Michael", "American Male"),
    // British Female
    ("bf_alice", "Alice", "British Female"),
    ("bf_emma", "Emma", "British Female"),
    ("bf_lily", "Lily", "British Female"),
    // British Male
    ("bm_daniel", "Daniel", "British Male"),
    ("bm_fable", "Fable", "British Male"),
    ("bm_george", "George", "British Male"),
    ("bm_lewis", "Lewis", "British Male"),
];

pub fn setup(app: &AppHandle) -> tauri::Result<()> {
    // Voice submenus grouped by category
    let mut af_items: Vec<CheckMenuItem<_>> = Vec::new();
    let mut am_items: Vec<CheckMenuItem<_>> = Vec::new();
    let mut bf_items: Vec<CheckMenuItem<_>> = Vec::new();
    let mut bm_items: Vec<CheckMenuItem<_>> = Vec::new();

    for &(id, name, group) in VOICES {
        let is_default = id == "af_sky";
        let item = CheckMenuItem::with_id(app, id, name, true, is_default, None::<&str>)?;
        match group {
            "American Female" => af_items.push(item),
            "American Male" => am_items.push(item),
            "British Female" => bf_items.push(item),
            "British Male" => bm_items.push(item),
            _ => {}
        }
    }

    // Build submenus
    let af_refs: Vec<&dyn tauri::menu::IsMenuItem<_>> = af_items.iter().map(|i| i as &dyn tauri::menu::IsMenuItem<_>).collect();
    let am_refs: Vec<&dyn tauri::menu::IsMenuItem<_>> = am_items.iter().map(|i| i as &dyn tauri::menu::IsMenuItem<_>).collect();
    let bf_refs: Vec<&dyn tauri::menu::IsMenuItem<_>> = bf_items.iter().map(|i| i as &dyn tauri::menu::IsMenuItem<_>).collect();
    let bm_refs: Vec<&dyn tauri::menu::IsMenuItem<_>> = bm_items.iter().map(|i| i as &dyn tauri::menu::IsMenuItem<_>).collect();

    let voice_af = Submenu::with_items(app, "American Female", true, &af_refs)?;
    let voice_am = Submenu::with_items(app, "American Male", true, &am_refs)?;
    let voice_bf = Submenu::with_items(app, "British Female", true, &bf_refs)?;
    let voice_bm = Submenu::with_items(app, "British Male", true, &bm_refs)?;

    let voices_menu = Submenu::with_items(
        app,
        "Voice",
        true,
        &[&voice_af, &voice_am, &voice_bf, &voice_bm],
    )?;

    // Design submenu
    let design_a = CheckMenuItem::with_id(app, "design_A", "Brutalist", true, false, None::<&str>)?;
    let design_b = CheckMenuItem::with_id(app, "design_B", "Industrial", true, false, None::<&str>)?;
    let design_c = CheckMenuItem::with_id(app, "design_C", "Clean", true, true, None::<&str>)?;
    let design_refs: Vec<&dyn tauri::menu::IsMenuItem<_>> = vec![&design_a, &design_b, &design_c];
    let design_menu = Submenu::with_items(app, "Design", true, &design_refs)?;

    let status = MenuItem::with_id(app, "status", "Loading model...", false, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;

    let menu = Menu::with_items(app, &[&status, &voices_menu, &design_menu, &quit])?;

    // Store all check items for unchecking
    let all_voice_ids: Vec<String> = VOICES.iter().map(|&(id, _, _)| id.to_string()).collect();
    let design_ids = vec!["design_A".to_string(), "design_B".to_string(), "design_C".to_string()];

    TrayIconBuilder::new()
        .menu(&menu)
        .tooltip("Murmur — Loading model...")
        .on_menu_event(move |app, event| {
            let id = event.id.as_ref();
            match id {
                "quit" => app.exit(0),
                _ => {
                    // Check if it's a voice selection
                    if all_voice_ids.contains(&id.to_string()) {
                        let _ = app.emit("voice-changed", serde_json::json!({ "voice": id }));
                    }
                    // Check if it's a design selection
                    if design_ids.contains(&id.to_string()) {
                        let design = id.replace("design_", "");
                        let _ = app.emit("design-changed", serde_json::json!({ "design": design }));
                    }
                }
            }
        })
        .build(app)?;

    // Listen for sidecar-ready to update status
    let app_clone = app.clone();
    tauri::async_runtime::spawn(async move {
        // Update tooltip after warmup (give it time)
        tokio::time::sleep(std::time::Duration::from_secs(15)).await;
        if let Some(tray) = app_clone.tray_by_id("main") {
            let _ = tray.set_tooltip(Some("Murmur — Ready (Ctrl+Alt+M)"));
        }
    });

    Ok(())
}
