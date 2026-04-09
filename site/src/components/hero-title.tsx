"use client";

import { useEffect, useState } from "react";

export function HeroTitle() {
  const [hidden, setHidden] = useState(false);

  useEffect(() => {
    const check = () => {
      const theme = document.documentElement.getAttribute("data-theme") || "serif";
      setHidden(theme === "kinetic");
    };
    check();
    const observer = new MutationObserver(() => check());
    observer.observe(document.documentElement, { attributes: true });
    return () => observer.disconnect();
  }, []);

  if (hidden) return null;

  return (
    <h1 className="font-display text-[clamp(64px,12vw,140px)] leading-[0.9] text-[var(--color-ink)] mb-6">
      murmur.
    </h1>
  );
}
