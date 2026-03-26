"use client";

export function PillWave() {
  const heights = [40, 70, 100, 60, 85, 45, 75, 30, 20];
  const delays = [0.1, 0.3, 0, 0.5, 0.2, 0.4, 0.1, 0.6, 0.7];

  return (
    <div className="flex items-center gap-[3px] h-6">
      <style>{`
        @keyframes pillPulse {
          0%, 100% { transform: scaleY(0.4); opacity: 0.5; }
          50% { transform: scaleY(1); opacity: 1; }
        }
      `}</style>
      {heights.map((h, i) => (
        <div
          key={i}
          className="w-[3px] rounded-full bg-[var(--color-accent)]"
          style={{
            height: `${h}%`,
            transformOrigin: "center",
            animation:
              i >= 7 ? "none" : `pillPulse 2s infinite ease-in-out`,
            animationDelay: `${delays[i]}s`,
            opacity: i >= 7 ? 0.3 : undefined,
          }}
        />
      ))}
    </div>
  );
}
