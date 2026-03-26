"use client";

import { useState } from "react";
import Image from "next/image";

const themes = [
  { id: "kinetic", label: "Kinetic", icon: "/theme-icons/kinetic-sm.png" },
  { id: "serif", label: "Serif", icon: "/theme-icons/serif-sm.png" },
  { id: "lilac", label: "Lilac", icon: "/theme-icons/lilac-sm.png" },
  { id: "editorial", label: "Editorial", icon: "/theme-icons/editorial-sm.png" },
  { id: "italic", label: "Italic", icon: "/theme-icons/italic-sm.png" },
];

export function ThemeToggle() {
  const [active, setActive] = useState("serif");

  const handleTheme = (id: string) => {
    setActive(id);
    document.documentElement.setAttribute("data-theme", id);
  };

  return (
    <div className="flex items-center gap-1 bg-black/5 rounded-full p-1">
      {themes.map((t) => (
        <button
          key={t.id}
          onClick={() => handleTheme(t.id)}
          title={t.label}
          className={`
            relative w-8 h-8 rounded-full flex items-center justify-center transition-all cursor-pointer
            ${active === t.id
              ? "bg-white shadow-sm scale-110"
              : "hover:bg-white/50"
            }
          `}
        >
          <Image
            src={t.icon}
            alt={t.label}
            width={20}
            height={20}
            className="object-contain"
          />
        </button>
      ))}
    </div>
  );
}
