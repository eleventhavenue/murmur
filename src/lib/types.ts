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
