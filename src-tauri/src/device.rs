use serde::Serialize;
use sysinfo::System;

#[derive(Debug, Serialize, Clone)]
pub struct GpuInfo {
    pub name: String,
    pub vendor: String,
    pub vram_mb: u64,
}

#[derive(Debug, Serialize, Clone)]
pub struct DeviceProfile {
    pub cpu_name: String,
    pub cpu_cores: usize,
    pub ram_total_mb: u64,
    pub ram_available_mb: u64,
    pub gpus: Vec<GpuInfo>,
    pub recommended_engine: String,
    pub engine_reason: String,
    pub tier: String,
}

/// Detect GPUs via DXGI (Windows only).
#[cfg(windows)]
fn detect_gpus() -> Vec<GpuInfo> {
    use windows::Win32::Graphics::Dxgi::*;

    let mut gpus = Vec::new();

    unsafe {
        let factory: Result<IDXGIFactory1, _> = CreateDXGIFactory1();
        let Ok(factory) = factory else {
            return gpus;
        };

        let mut i = 0u32;
        loop {
            let adapter = factory.EnumAdapters1(i);
            let Ok(adapter) = adapter else { break };

            let Ok(desc) = adapter.GetDesc1() else {
                i += 1;
                continue;
            };

            // Skip software/basic render drivers
            if desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE.0 as u32 != 0 {
                i += 1;
                continue;
            }

            let name = String::from_utf16_lossy(&desc.Description)
                .trim_end_matches('\0')
                .to_string();

            let vendor = match desc.VendorId {
                0x10DE => "NVIDIA".to_string(),
                0x1002 => "AMD".to_string(),
                0x8086 => "Intel".to_string(),
                v => format!("Unknown ({:#06X})", v),
            };

            let vram_mb = desc.DedicatedVideoMemory as u64 / (1024 * 1024);

            // Skip integrated GPUs with 0 dedicated VRAM (or very low)
            // but still include them in the list
            gpus.push(GpuInfo {
                name,
                vendor,
                vram_mb,
            });

            i += 1;
        }
    }

    gpus
}

#[cfg(not(windows))]
fn detect_gpus() -> Vec<GpuInfo> {
    // TODO: Linux/Mac GPU detection
    Vec::new()
}

/// Determine the best TTS engine based on hardware.
fn recommend_engine(gpus: &[GpuInfo], cpu_cores: usize, ram_mb: u64) -> (String, String, String) {
    // Find the best discrete GPU
    let best_gpu = gpus
        .iter()
        .filter(|g| g.vendor == "NVIDIA" || g.vendor == "AMD")
        .max_by_key(|g| g.vram_mb);

    if let Some(gpu) = best_gpu {
        if gpu.vram_mb >= 8192 {
            // 8GB+ VRAM — kokoro on GPU, fast inference
            return (
                "kokoro-gpu".into(),
                format!(
                    "{} with {}MB VRAM — kokoro runs fast on GPU",
                    gpu.name, gpu.vram_mb
                ),
                "high".into(),
            );
        }
        if gpu.vram_mb >= 4096 {
            // 4-8GB VRAM — kokoro on CPU (model doesn't fit well in VRAM)
            return (
                "kokoro-cpu".into(),
                format!(
                    "{} with {}MB VRAM — kokoro on CPU (GPU VRAM tight for model)",
                    gpu.name, gpu.vram_mb
                ),
                "medium".into(),
            );
        }
    }

    // No discrete GPU or very low VRAM — check CPU strength
    if cpu_cores >= 4 && ram_mb >= 4096 {
        return (
            "kokoro-cpu".into(),
            format!(
                "{} cores, {}MB RAM — kokoro on CPU",
                cpu_cores, ram_mb
            ),
            "medium".into(),
        );
    }

    if cpu_cores >= 2 && ram_mb >= 2048 {
        // Weaker machine — use piper (much lighter, MIT license)
        return (
            "piper".into(),
            format!(
                "{} cores, {}MB RAM — piper recommended (lightweight)",
                cpu_cores, ram_mb
            ),
            "low".into(),
        );
    }

    // Very weak hardware — suggest cloud
    (
        "cloud".into(),
        "Limited hardware — cloud TTS recommended for best experience".into(),
        "minimal".into(),
    )
}

#[tauri::command]
pub fn get_device_profile() -> DeviceProfile {
    let mut sys = System::new_all();
    sys.refresh_all();

    let cpu_name = sys
        .cpus()
        .first()
        .map(|c| c.brand().to_string())
        .unwrap_or_else(|| "Unknown".into());

    let cpu_cores = sys.cpus().len();
    let ram_total_mb = sys.total_memory() / (1024 * 1024);
    let ram_available_mb = sys.available_memory() / (1024 * 1024);

    let gpus = detect_gpus();
    let (recommended_engine, engine_reason, tier) =
        recommend_engine(&gpus, cpu_cores, ram_total_mb);

    DeviceProfile {
        cpu_name,
        cpu_cores,
        ram_total_mb,
        ram_available_mb,
        gpus,
        recommended_engine,
        engine_reason,
        tier,
    }
}
