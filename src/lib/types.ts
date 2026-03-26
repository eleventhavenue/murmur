export interface Voice {
  id: string;
  name: string;
  group: string;
}

export interface TTSState {
  status: "idle" | "loading" | "playing" | "paused";
  text: string;
  voice: Voice | null;
  progress: number;
}

export interface HotkeyPayload {
  text: string;
}

export interface GpuInfo {
  name: string;
  vendor: string;
  vram_mb: number;
}

export interface DeviceProfile {
  cpu_name: string;
  cpu_cores: number;
  ram_total_mb: number;
  ram_available_mb: number;
  gpus: GpuInfo[];
  recommended_engine: string;
  engine_reason: string;
  /** "high" | "medium" | "low" | "minimal" */
  tier: string;
}
