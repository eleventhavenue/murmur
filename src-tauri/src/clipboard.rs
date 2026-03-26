use tauri::AppHandle;
use tauri_plugin_clipboard_manager::ClipboardExt;

/// Simulate Ctrl+C to copy the currently selected text, then read from clipboard.
pub fn capture_selection(app: &AppHandle) -> Option<String> {
    #[cfg(windows)]
    {
        simulate_copy();
        std::thread::sleep(std::time::Duration::from_millis(80));
    }

    app.clipboard().read_text().ok()
}

#[cfg(windows)]
fn simulate_copy() {
    use windows::Win32::UI::Input::KeyboardAndMouse::*;

    // Release Alt and M (user is holding Ctrl+Alt+M when hotkey fires)
    // Then press Ctrl+C, then release
    let inputs = [
        key_input(VK_MENU, true),      // release Alt
        key_input(VK_M, true),         // release M
        key_input(VK_CONTROL, false),  // press Ctrl
        key_input(VK_C, false),        // press C
        key_input(VK_C, true),         // release C
        key_input(VK_CONTROL, true),   // release Ctrl
    ];

    unsafe {
        let _ = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
    }
}

#[cfg(windows)]
fn key_input(vk: windows::Win32::UI::Input::KeyboardAndMouse::VIRTUAL_KEY, key_up: bool) -> windows::Win32::UI::Input::KeyboardAndMouse::INPUT {
    use windows::Win32::UI::Input::KeyboardAndMouse::*;

    let flags = if key_up {
        KEYEVENTF_KEYUP
    } else {
        KEYBD_EVENT_FLAGS(0)
    };

    INPUT {
        r#type: INPUT_KEYBOARD,
        Anonymous: INPUT_0 {
            ki: KEYBDINPUT {
                wVk: vk,
                wScan: 0,
                dwFlags: flags,
                time: 0,
                dwExtraInfo: 0,
            },
        },
    }
}
