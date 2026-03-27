"use client";

import { useState } from "react";
import Image from "next/image";

const themes = [
  { id: "kinetic", label: "Kinetic", icon: "/theme-icons/kinetic.png" },
  { id: "serif", label: "Serif", icon: "/theme-icons/serif.png" },
  { id: "lilac", label: "Lilac", icon: "/theme-icons/lilac.png" },
  { id: "editorial", label: "Editorial", icon: "/theme-icons/editorial.png" },
  { id: "italic", label: "Italic", icon: "/theme-icons/italic.png" },
];

export function ThemeToggle() {
  const [active, setActive] = useState("serif");

  const handleTheme = (id: string) => {
    setActive(id);
    document.documentElement.setAttribute("data-theme", id);
  };

  return (
    <div className="flex items-center gap-1.5 bg-black/5 rounded-full p-1.5">
      {themes.map((t) => (
        <button
          key={t.id}
          onClick={() => handleTheme(t.id)}
          title={t.label}
          className={`
            relative w-11 h-11 rounded-full flex items-center justify-center transition-all cursor-pointer
            ${active === t.id
              ? "bg-white shadow-md scale-110"
              : "hover:bg-white/50"
            }
          `}
        >
          <Image
            src={t.icon}
            alt={t.label}
            width={28}
            height={28}
            className="object-contain"
          />
        </button>
      ))}
    </div>
  );
}
